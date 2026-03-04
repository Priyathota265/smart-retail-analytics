-- ============================================================
-- FILE: 01_create_schema.sql
-- PROJECT: Smart Retail Analytics Platform
-- DESCRIPTION: Star Schema DDL for RetailEdge Data Warehouse
-- AUTHOR: Priyadarshini Thota
-- ============================================================

-- ─────────────────────────────────────────
-- CREATE DATABASE & SCHEMA
-- ─────────────────────────────────────────
CREATE DATABASE RetailEdgeDW;
GO

USE RetailEdgeDW;
GO

CREATE SCHEMA dwh;
GO
CREATE SCHEMA staging;
GO

-- ─────────────────────────────────────────
-- DIMENSION TABLES
-- ─────────────────────────────────────────

-- DIM: Date
CREATE TABLE dwh.DimDate (
    DateKey         INT PRIMARY KEY,           -- YYYYMMDD
    FullDate        DATE NOT NULL,
    DayOfWeek       TINYINT,
    DayName         VARCHAR(10),
    WeekOfYear      TINYINT,
    MonthNumber     TINYINT,
    MonthName       VARCHAR(10),
    Quarter         TINYINT,
    Year            SMALLINT,
    IsWeekend       BIT DEFAULT 0,
    IsHoliday       BIT DEFAULT 0,
    FiscalYear      SMALLINT,
    FiscalQuarter   TINYINT
);
GO

-- DIM: Customer
CREATE TABLE dwh.DimCustomer (
    CustomerKey         INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID          VARCHAR(20) NOT NULL UNIQUE,
    FirstName           VARCHAR(50),
    LastName            VARCHAR(50),
    Email               VARCHAR(100),
    Segment             VARCHAR(30),           -- 'Premium', 'Regular', 'At-Risk'
    Region              VARCHAR(50),
    State               VARCHAR(30),
    City                VARCHAR(50),
    ZipCode             VARCHAR(10),
    JoinDate            DATE,
    IsActive            BIT DEFAULT 1,
    ChurnRiskScore      DECIMAL(5,4),          -- AI model output (0.0000–1.0000)
    ChurnRiskCategory   VARCHAR(20),           -- 'Low', 'Medium', 'High'
    LastScoredDate      DATE,
    RowInsertedDate     DATETIME DEFAULT GETDATE()
);
GO

-- DIM: Product
CREATE TABLE dwh.DimProduct (
    ProductKey          INT IDENTITY(1,1) PRIMARY KEY,
    ProductID           VARCHAR(20) NOT NULL UNIQUE,
    ProductName         VARCHAR(100),
    Category            VARCHAR(50),
    SubCategory         VARCHAR(50),
    Brand               VARCHAR(50),
    UnitCost            DECIMAL(10,2),
    UnitPrice           DECIMAL(10,2),
    GrossMarginPct      AS (CASE WHEN UnitPrice > 0
                              THEN ROUND((UnitPrice - UnitCost) / UnitPrice * 100, 2)
                              ELSE 0 END) PERSISTED,
    IsActive            BIT DEFAULT 1,
    RowInsertedDate     DATETIME DEFAULT GETDATE()
);
GO

-- DIM: Store
CREATE TABLE dwh.DimStore (
    StoreKey        INT IDENTITY(1,1) PRIMARY KEY,
    StoreID         VARCHAR(20) NOT NULL UNIQUE,
    StoreName       VARCHAR(100),
    Region          VARCHAR(50),
    State           VARCHAR(30),
    City            VARCHAR(50),
    StoreType       VARCHAR(30),       -- 'Physical', 'Online', 'Outlet'
    OpenDate        DATE,
    IsActive        BIT DEFAULT 1,
    RowInsertedDate DATETIME DEFAULT GETDATE()
);
GO

-- ─────────────────────────────────────────
-- FACT TABLES
-- ─────────────────────────────────────────

-- FACT: Sales
CREATE TABLE dwh.FactSales (
    SalesKey            BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderID             VARCHAR(30) NOT NULL,
    OrderLineID         INT NOT NULL,
    DateKey             INT NOT NULL,
    CustomerKey         INT NOT NULL,
    ProductKey          INT NOT NULL,
    StoreKey            INT NOT NULL,
    Quantity            INT,
    UnitPrice           DECIMAL(10,2),
    Discount            DECIMAL(5,2) DEFAULT 0,
    GrossSales          AS (Quantity * UnitPrice) PERSISTED,
    NetSales            AS (Quantity * UnitPrice * (1 - Discount / 100)) PERSISTED,
    COGS                DECIMAL(10,2),
    GrossProfit         AS (Quantity * UnitPrice * (1 - Discount / 100) - COGS) PERSISTED,
    ReturnFlag          BIT DEFAULT 0,
    RowInsertedDate     DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_FactSales_Date     FOREIGN KEY (DateKey)     REFERENCES dwh.DimDate(DateKey),
    CONSTRAINT FK_FactSales_Customer FOREIGN KEY (CustomerKey) REFERENCES dwh.DimCustomer(CustomerKey),
    CONSTRAINT FK_FactSales_Product  FOREIGN KEY (ProductKey)  REFERENCES dwh.DimProduct(ProductKey),
    CONSTRAINT FK_FactSales_Store    FOREIGN KEY (StoreKey)    REFERENCES dwh.DimStore(StoreKey)
);
GO

-- FACT: Inventory Snapshot (daily)
CREATE TABLE dwh.FactInventory (
    InventoryKey        BIGINT IDENTITY(1,1) PRIMARY KEY,
    DateKey             INT NOT NULL,
    ProductKey          INT NOT NULL,
    StoreKey            INT NOT NULL,
    QuantityOnHand      INT,
    ReorderPoint        INT,
    DaysOfSupply        INT,
    StockOutRisk        VARCHAR(10),   -- 'Low', 'Medium', 'High'
    OverstockFlag       BIT DEFAULT 0,
    RowInsertedDate     DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_FactInv_Date    FOREIGN KEY (DateKey)    REFERENCES dwh.DimDate(DateKey),
    CONSTRAINT FK_FactInv_Product FOREIGN KEY (ProductKey) REFERENCES dwh.DimProduct(ProductKey),
    CONSTRAINT FK_FactInv_Store   FOREIGN KEY (StoreKey)   REFERENCES dwh.DimStore(StoreKey)
);
GO

-- FACT: Customer Activity (for churn features)
CREATE TABLE dwh.FactCustomerActivity (
    ActivityKey             BIGINT IDENTITY(1,1) PRIMARY KEY,
    CustomerKey             INT NOT NULL,
    DateKey                 INT NOT NULL,
    TotalOrders             INT,
    TotalSpend              DECIMAL(12,2),
    AvgOrderValue           DECIMAL(10,2),
    DaysSinceLastPurchase   INT,
    UniqueCategories        INT,
    SupportTickets          INT,
    RowInsertedDate         DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_FactCA_Customer FOREIGN KEY (CustomerKey) REFERENCES dwh.DimCustomer(CustomerKey),
    CONSTRAINT FK_FactCA_Date     FOREIGN KEY (DateKey)     REFERENCES dwh.DimDate(DateKey)
);
GO

-- ─────────────────────────────────────────
-- AI INSIGHTS TABLE (GPT output storage)
-- ─────────────────────────────────────────
CREATE TABLE dwh.AIInsights (
    InsightKey      INT IDENTITY(1,1) PRIMARY KEY,
    InsightDate     DATE NOT NULL,
    InsightArea     VARCHAR(50),      -- 'Revenue', 'Churn', 'Inventory', 'Overall'
    InsightText     NVARCHAR(MAX),    -- GPT-4 generated narrative
    KPIContext      NVARCHAR(MAX),    -- JSON of KPIs sent to GPT
    ModelVersion    VARCHAR(20),
    GeneratedAt     DATETIME DEFAULT GETDATE()
);
GO

-- ─────────────────────────────────────────
-- INDEXES FOR PERFORMANCE
-- ─────────────────────────────────────────
CREATE INDEX IX_FactSales_DateKey     ON dwh.FactSales(DateKey);
CREATE INDEX IX_FactSales_CustomerKey ON dwh.FactSales(CustomerKey);
CREATE INDEX IX_FactSales_ProductKey  ON dwh.FactSales(ProductKey);
CREATE INDEX IX_DimCustomer_Churn     ON dwh.DimCustomer(ChurnRiskCategory, IsActive);
GO

PRINT 'Schema created successfully — RetailEdgeDW';
GO
