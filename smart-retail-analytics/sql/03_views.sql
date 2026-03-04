-- ============================================================
-- FILE: 03_views.sql
-- PROJECT: Smart Retail Analytics Platform
-- DESCRIPTION: Reporting Views consumed by Power BI
-- AUTHOR: Priyadarshini Thota
-- ============================================================

USE RetailEdgeDW;
GO

-- ─────────────────────────────────────────
-- VIEW 1: Sales Summary (Executive Overview)
-- ─────────────────────────────────────────
CREATE OR ALTER VIEW dwh.vw_SalesSummary AS
SELECT
    d.Year,
    d.Quarter,
    d.MonthNumber,
    d.MonthName,
    d.FullDate,
    st.Region,
    st.State,
    st.StoreType,
    p.Category,
    p.SubCategory,
    p.Brand,
    c.Segment         AS CustomerSegment,
    SUM(f.GrossSales) AS GrossSales,
    SUM(f.NetSales)   AS NetSales,
    SUM(f.GrossProfit)AS GrossProfit,
    SUM(f.Quantity)   AS UnitsSold,
    COUNT(DISTINCT f.OrderID)     AS OrderCount,
    COUNT(DISTINCT f.CustomerKey) AS UniqueCustomers,
    ROUND(SUM(f.GrossProfit) / NULLIF(SUM(f.NetSales),0) * 100, 2) AS GrossMarginPct
FROM dwh.FactSales f
JOIN dwh.DimDate     d  ON f.DateKey     = d.DateKey
JOIN dwh.DimStore    st ON f.StoreKey    = st.StoreKey
JOIN dwh.DimProduct  p  ON f.ProductKey  = p.ProductKey
JOIN dwh.DimCustomer c  ON f.CustomerKey = c.CustomerKey
WHERE f.ReturnFlag = 0
GROUP BY
    d.Year, d.Quarter, d.MonthNumber, d.MonthName, d.FullDate,
    st.Region, st.State, st.StoreType,
    p.Category, p.SubCategory, p.Brand, c.Segment;
GO


-- ─────────────────────────────────────────
-- VIEW 2: Churn Risk Dashboard
-- ─────────────────────────────────────────
CREATE OR ALTER VIEW dwh.vw_ChurnRiskDashboard AS
SELECT
    c.CustomerID,
    c.FirstName + ' ' + c.LastName   AS CustomerName,
    c.Segment,
    c.Region,
    c.State,
    c.ChurnRiskScore,
    c.ChurnRiskCategory,
    c.LastScoredDate,
    ca.TotalOrders,
    ca.TotalSpend,
    ca.AvgOrderValue,
    ca.DaysSinceLastPurchase,
    ca.UniqueCategories,
    ca.SupportTickets,
    -- Estimated revenue at risk
    ca.AvgOrderValue * 12            AS EstimatedAnnualValue,
    CASE c.ChurnRiskCategory
        WHEN 'High'   THEN ca.AvgOrderValue * 12 * 0.85
        WHEN 'Medium' THEN ca.AvgOrderValue * 12 * 0.45
        ELSE 0
    END                              AS RevenueAtRisk
FROM dwh.DimCustomer c
LEFT JOIN dwh.FactCustomerActivity ca ON c.CustomerKey = ca.CustomerKey
WHERE c.IsActive = 1;
GO


-- ─────────────────────────────────────────
-- VIEW 3: Inventory Intelligence
-- ─────────────────────────────────────────
CREATE OR ALTER VIEW dwh.vw_InventoryIntelligence AS
SELECT
    p.ProductID,
    p.ProductName,
    p.Category,
    p.SubCategory,
    p.Brand,
    st.StoreName,
    st.Region,
    st.State,
    i.QuantityOnHand,
    i.ReorderPoint,
    i.DaysOfSupply,
    i.StockOutRisk,
    i.OverstockFlag,
    p.UnitCost * i.QuantityOnHand    AS InventoryValue,
    CASE i.OverstockFlag
        WHEN 1 THEN p.UnitCost * (i.QuantityOnHand - i.ReorderPoint * 2)
        ELSE 0
    END                              AS OverstockCost,
    d.FullDate                       AS SnapshotDate
FROM dwh.FactInventory i
JOIN dwh.DimProduct p  ON i.ProductKey = p.ProductKey
JOIN dwh.DimStore   st ON i.StoreKey   = st.StoreKey
JOIN dwh.DimDate    d  ON i.DateKey    = d.DateKey
WHERE d.FullDate = (SELECT MAX(FullDate) FROM dwh.DimDate dd
                    JOIN dwh.FactInventory fi ON dd.DateKey = fi.DateKey);
GO


-- ─────────────────────────────────────────
-- VIEW 4: KPI Summary (for GPT context + Power BI cards)
-- ─────────────────────────────────────────
CREATE OR ALTER VIEW dwh.vw_KPISummary AS
SELECT
    'Current Month'                              AS Period,
    SUM(f.NetSales)                              AS TotalRevenue,
    SUM(f.GrossProfit)                           AS TotalGrossProfit,
    ROUND(SUM(f.GrossProfit)/NULLIF(SUM(f.NetSales),0)*100,2) AS GrossMarginPct,
    COUNT(DISTINCT f.OrderID)                    AS TotalOrders,
    COUNT(DISTINCT f.CustomerKey)                AS ActiveCustomers,
    ROUND(SUM(f.NetSales)/NULLIF(COUNT(DISTINCT f.CustomerKey),0),2) AS AvgRevenuePerCustomer,
    (SELECT COUNT(*) FROM dwh.DimCustomer
     WHERE ChurnRiskCategory = 'High' AND IsActive = 1) AS HighChurnCustomers,
    (SELECT SUM(RevenueAtRisk) FROM dwh.vw_ChurnRiskDashboard
     WHERE ChurnRiskCategory = 'High')           AS TotalRevenueAtRisk,
    (SELECT COUNT(*) FROM dwh.vw_InventoryIntelligence
     WHERE StockOutRisk = 'High')                AS HighStockOutSKUs
FROM dwh.FactSales f
JOIN dwh.DimDate d ON f.DateKey = d.DateKey
WHERE d.Year  = YEAR(GETDATE())
  AND d.MonthNumber = MONTH(GETDATE())
  AND f.ReturnFlag = 0;
GO

PRINT 'All views created successfully.';
GO
