-- ============================================================
-- FILE: 02_stored_procedures.sql
-- PROJECT: Smart Retail Analytics Platform
-- DESCRIPTION: ETL Transformation Stored Procedures
-- AUTHOR: Priyadarshini Thota
-- ============================================================

USE RetailEdgeDW;
GO

-- ─────────────────────────────────────────
-- SP 1: Load & Validate Sales Staging → DW
-- ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE dwh.usp_LoadFactSales
    @BatchDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @BatchDate = ISNULL(@BatchDate, CAST(GETDATE() AS DATE));

    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsRejected INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Data quality check on staging
        IF EXISTS (
            SELECT 1 FROM staging.SalesRaw
            WHERE OrderID IS NULL OR Quantity <= 0 OR UnitPrice < 0
        )
        BEGIN
            -- Log rejects
            INSERT INTO staging.SalesRejects (OrderID, RejectReason, RejectDate)
            SELECT OrderID, 'NULL OrderID or invalid Qty/Price', GETDATE()
            FROM staging.SalesRaw
            WHERE OrderID IS NULL OR Quantity <= 0 OR UnitPrice < 0;

            SET @RowsRejected = @@ROWCOUNT;
        END

        -- Step 2: Insert valid records to FactSales
        INSERT INTO dwh.FactSales (
            OrderID, OrderLineID, DateKey, CustomerKey, ProductKey,
            StoreKey, Quantity, UnitPrice, Discount, COGS, ReturnFlag
        )
        SELECT
            s.OrderID,
            s.OrderLineID,
            CAST(FORMAT(s.OrderDate, 'yyyyMMdd') AS INT) AS DateKey,
            c.CustomerKey,
            p.ProductKey,
            st.StoreKey,
            s.Quantity,
            s.UnitPrice,
            ISNULL(s.Discount, 0),
            p.UnitCost * s.Quantity AS COGS,
            ISNULL(s.ReturnFlag, 0)
        FROM staging.SalesRaw s
        INNER JOIN dwh.DimCustomer  c  ON s.CustomerID = c.CustomerID
        INNER JOIN dwh.DimProduct   p  ON s.ProductID  = p.ProductID
        INNER JOIN dwh.DimStore     st ON s.StoreID    = st.StoreID
        WHERE s.OrderID IS NOT NULL
          AND s.Quantity > 0
          AND s.UnitPrice >= 0
          AND NOT EXISTS (
              SELECT 1 FROM dwh.FactSales f
              WHERE f.OrderID = s.OrderID AND f.OrderLineID = s.OrderLineID
          );

        SET @RowsInserted = @@ROWCOUNT;

        -- Step 3: Archive processed staging records
        UPDATE staging.SalesRaw
        SET ProcessedFlag = 1, ProcessedDate = GETDATE()
        WHERE ProcessedFlag = 0;

        COMMIT TRANSACTION;

        -- Log result
        PRINT CONCAT('usp_LoadFactSales complete | Inserted: ', @RowsInserted,
                     ' | Rejected: ', @RowsRejected,
                     ' | BatchDate: ', @BatchDate);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(500) = ERROR_MESSAGE();
        RAISERROR('usp_LoadFactSales FAILED: %s', 16, 1, @ErrMsg);
    END CATCH
END;
GO


-- ─────────────────────────────────────────
-- SP 2: Refresh Customer Activity Features
-- (used as input to AI churn model)
-- ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE dwh.usp_RefreshCustomerActivity
AS
BEGIN
    SET NOCOUNT ON;

    -- Truncate and reload (full refresh for feature engineering)
    TRUNCATE TABLE dwh.FactCustomerActivity;

    INSERT INTO dwh.FactCustomerActivity (
        CustomerKey, DateKey, TotalOrders, TotalSpend,
        AvgOrderValue, DaysSinceLastPurchase, UniqueCategories, SupportTickets
    )
    SELECT
        c.CustomerKey,
        CAST(FORMAT(GETDATE(), 'yyyyMMdd') AS INT) AS DateKey,
        COUNT(DISTINCT f.OrderID)                  AS TotalOrders,
        SUM(f.NetSales)                            AS TotalSpend,
        AVG(f.NetSales)                            AS AvgOrderValue,
        DATEDIFF(DAY, MAX(d.FullDate), GETDATE())  AS DaysSinceLastPurchase,
        COUNT(DISTINCT p.Category)                 AS UniqueCategories,
        ISNULL(t.TicketCount, 0)                   AS SupportTickets
    FROM dwh.DimCustomer c
    LEFT JOIN dwh.FactSales f      ON c.CustomerKey = f.CustomerKey
    LEFT JOIN dwh.DimDate d        ON f.DateKey = d.DateKey
    LEFT JOIN dwh.DimProduct p     ON f.ProductKey = p.ProductKey
    LEFT JOIN (
        SELECT CustomerID, COUNT(*) AS TicketCount
        FROM staging.SupportTickets
        WHERE CreatedDate >= DATEADD(MONTH, -6, GETDATE())
        GROUP BY CustomerID
    ) t ON c.CustomerID = t.CustomerID
    WHERE c.IsActive = 1
    GROUP BY c.CustomerKey, t.TicketCount;

    PRINT CONCAT('usp_RefreshCustomerActivity complete | Rows: ', @@ROWCOUNT);
END;
GO


-- ─────────────────────────────────────────
-- SP 3: Apply AI Churn Scores back to DimCustomer
-- (called after Python model runs)
-- ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE dwh.usp_ApplyChurnScores
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
    SET
        c.ChurnRiskScore    = cs.ChurnProbability,
        c.ChurnRiskCategory = CASE
            WHEN cs.ChurnProbability >= 0.70 THEN 'High'
            WHEN cs.ChurnProbability >= 0.40 THEN 'Medium'
            ELSE 'Low'
        END,
        c.LastScoredDate = GETDATE()
    FROM dwh.DimCustomer c
    INNER JOIN staging.ChurnScores cs ON c.CustomerID = cs.CustomerID;

    PRINT CONCAT('usp_ApplyChurnScores complete | Rows updated: ', @@ROWCOUNT);
END;
GO


-- ─────────────────────────────────────────
-- SP 4: Refresh Inventory Snapshot
-- ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE dwh.usp_RefreshInventorySnapshot
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayKey INT = CAST(FORMAT(GETDATE(), 'yyyyMMdd') AS INT);

    -- Delete today's snapshot if exists (idempotent)
    DELETE FROM dwh.FactInventory WHERE DateKey = @TodayKey;

    INSERT INTO dwh.FactInventory (
        DateKey, ProductKey, StoreKey, QuantityOnHand,
        ReorderPoint, DaysOfSupply, StockOutRisk, OverstockFlag
    )
    SELECT
        @TodayKey,
        p.ProductKey,
        st.StoreKey,
        i.QuantityOnHand,
        i.ReorderPoint,
        -- Days of supply = on-hand / avg daily sales (last 30 days)
        CASE WHEN ISNULL(avg_sales.AvgDailySales, 0) = 0 THEN 999
             ELSE CAST(i.QuantityOnHand / avg_sales.AvgDailySales AS INT)
        END AS DaysOfSupply,
        CASE
            WHEN i.QuantityOnHand = 0 THEN 'High'
            WHEN i.QuantityOnHand <= i.ReorderPoint THEN 'Medium'
            ELSE 'Low'
        END AS StockOutRisk,
        CASE WHEN i.QuantityOnHand > i.ReorderPoint * 3 THEN 1 ELSE 0 END AS OverstockFlag
    FROM staging.InventoryRaw i
    INNER JOIN dwh.DimProduct p  ON i.ProductID = p.ProductID
    INNER JOIN dwh.DimStore   st ON i.StoreID   = st.StoreID
    LEFT JOIN (
        SELECT ProductKey, StoreKey,
               CAST(SUM(Quantity) AS FLOAT) / 30.0 AS AvgDailySales
        FROM dwh.FactSales
        WHERE DateKey >= CAST(FORMAT(DATEADD(DAY,-30,GETDATE()),'yyyyMMdd') AS INT)
        GROUP BY ProductKey, StoreKey
    ) avg_sales ON p.ProductKey = avg_sales.ProductKey
               AND st.StoreKey  = avg_sales.StoreKey;

    PRINT CONCAT('usp_RefreshInventorySnapshot complete | DateKey: ', @TodayKey,
                 ' | Rows: ', @@ROWCOUNT);
END;
GO

PRINT 'All stored procedures created successfully.';
GO
