# DAX Measures – RetailEdge Power BI Dashboard

All DAX measures used across the 4 dashboard pages. Paste into Power BI Desktop's DAX editor.

---

## 📊 Page 1: Executive Overview

```dax
-- Total Net Sales
Total Net Sales =
SUM(vw_SalesSummary[NetSales])

-- Total Gross Profit
Total Gross Profit =
SUM(vw_SalesSummary[GrossProfit])

-- Gross Margin %
Gross Margin % =
DIVIDE([Total Gross Profit], [Total Net Sales], 0)

-- Sales vs Prior Year (YoY)
Sales YoY % Change =
VAR CurrentYearSales = [Total Net Sales]
VAR PriorYearSales =
    CALCULATE([Total Net Sales],
        SAMEPERIODLASTYEAR(DimDate[FullDate]))
RETURN
    DIVIDE(CurrentYearSales - PriorYearSales, PriorYearSales, 0)

-- Running YTD Sales
YTD Net Sales =
TOTALYTD([Total Net Sales], DimDate[FullDate])

-- Average Order Value
Avg Order Value =
DIVIDE([Total Net Sales], DISTINCTCOUNT(vw_SalesSummary[OrderCount]), 0)

-- Revenue Target (static or from targets table)
Revenue Target =
CALCULATE(SUM(Targets[MonthlyTarget]),
    FILTER(Targets, Targets[Month] = MONTH(TODAY()) && Targets[Year] = YEAR(TODAY())))

-- Target Attainment %
Target Attainment % =
DIVIDE([Total Net Sales], [Revenue Target], 0)
```

---

## 🔴 Page 2: Customer Churn Analysis

```dax
-- Total High-Risk Customers
High Risk Customers =
CALCULATE(
    COUNTROWS(vw_ChurnRiskDashboard),
    vw_ChurnRiskDashboard[ChurnRiskCategory] = "High"
)

-- Total Revenue at Risk
Total Revenue At Risk =
CALCULATE(
    SUM(vw_ChurnRiskDashboard[RevenueAtRisk]),
    vw_ChurnRiskDashboard[ChurnRiskCategory] IN {"High","Medium"}
)

-- Average Churn Score
Avg Churn Risk Score =
AVERAGE(vw_ChurnRiskDashboard[ChurnRiskScore])

-- Churn Risk Distribution (used in donut chart)
Churn Customer Count by Category =
CALCULATE(
    COUNTROWS(vw_ChurnRiskDashboard),
    ALLEXCEPT(vw_ChurnRiskDashboard, vw_ChurnRiskDashboard[ChurnRiskCategory])
)

-- 10% Retention Uplift Impact ($)
Retention Uplift 10pct =
[Total Revenue At Risk] * 0.10

-- Days Since Last Purchase (avg for selected segment)
Avg Days Since Purchase =
AVERAGE(vw_ChurnRiskDashboard[DaysSinceLastPurchase])
```

---

## 📦 Page 3: Inventory Intelligence

```dax
-- Total Inventory Value
Total Inventory Value =
SUM(vw_InventoryIntelligence[InventoryValue])

-- Overstock Cost
Total Overstock Cost =
SUM(vw_InventoryIntelligence[OverstockCost])

-- High StockOut SKU Count
High StockOut SKUs =
CALCULATE(
    COUNTROWS(vw_InventoryIntelligence),
    vw_InventoryIntelligence[StockOutRisk] = "High"
)

-- Avg Days of Supply
Avg Days Of Supply =
AVERAGEX(
    FILTER(vw_InventoryIntelligence, vw_InventoryIntelligence[DaysOfSupply] < 999),
    vw_InventoryIntelligence[DaysOfSupply]
)

-- % Products with Overstock
Overstock Rate % =
DIVIDE(
    CALCULATE(COUNTROWS(vw_InventoryIntelligence),
              vw_InventoryIntelligence[OverstockFlag] = 1),
    COUNTROWS(vw_InventoryIntelligence),
    0
)
```

---

## 🤖 Page 4: AI Insights

```dax
-- Latest GPT Revenue Insight
GPT Revenue Insight =
CALCULATE(
    FIRSTNONBLANK(AIInsights[InsightText], 1),
    AIInsights[InsightArea] = "Revenue",
    AIInsights[InsightDate] = MAX(AIInsights[InsightDate])
)

-- Latest GPT Churn Insight
GPT Churn Insight =
CALCULATE(
    FIRSTNONBLANK(AIInsights[InsightText], 1),
    AIInsights[InsightArea] = "Churn",
    AIInsights[InsightDate] = MAX(AIInsights[InsightDate])
)

-- Latest GPT Inventory Insight
GPT Inventory Insight =
CALCULATE(
    FIRSTNONBLANK(AIInsights[InsightText], 1),
    AIInsights[InsightArea] = "Inventory",
    AIInsights[InsightDate] = MAX(AIInsights[InsightDate])
)

-- Latest GPT Executive Summary
GPT Executive Summary =
CALCULATE(
    FIRSTNONBLANK(AIInsights[InsightText], 1),
    AIInsights[InsightArea] = "Overall",
    AIInsights[InsightDate] = MAX(AIInsights[InsightDate])
)

-- Last Insight Generated (subtitle for page)
Insights Last Updated =
"AI insights generated: " & FORMAT(MAX(AIInsights[InsightDate]), "MMM DD, YYYY")
```

---

## 🔒 Row-Level Security (RLS)

```dax
-- Region RLS filter (apply to DimStore table)
-- In Power BI Desktop → Modeling → Manage Roles → Create "RegionManagers" role:
[Region] = USERPRINCIPALNAME()
-- Map each user email to their region in the mapping table.
```

---

## 📌 Notes
- All measures use `vw_*` views as data sources (imported via DirectQuery or Import mode)
- Date table `DimDate` is marked as the official Date Table in Power BI
- RLS roles: `RegionManagers`, `StoreManagers`, `Executives` (full access)
