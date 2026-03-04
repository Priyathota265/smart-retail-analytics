# Data Dictionary – Smart Retail Analytics Platform

## dwh.DimCustomer

| Column | Type | Description |
|---|---|---|
| CustomerKey | INT | Surrogate key |
| CustomerID | VARCHAR(20) | Source system customer ID |
| Segment | VARCHAR(30) | Premium / Regular / At-Risk |
| ChurnRiskScore | DECIMAL(5,4) | AI model churn probability (0.0–1.0) |
| ChurnRiskCategory | VARCHAR(20) | Low / Medium / High (derived from score) |
| LastScoredDate | DATE | Date AI model last ran for this customer |

## dwh.FactSales

| Column | Type | Description |
|---|---|---|
| GrossSales | Computed | Quantity × UnitPrice |
| NetSales | Computed | GrossSales × (1 – Discount%) |
| GrossProfit | Computed | NetSales – COGS |
| ReturnFlag | BIT | 1 = returned order (excluded from KPIs) |

## dwh.AIInsights

| Column | Type | Description |
|---|---|---|
| InsightArea | VARCHAR(50) | Revenue / Churn / Inventory / Overall |
| InsightText | NVARCHAR(MAX) | GPT-4 generated narrative text |
| KPIContext | NVARCHAR(MAX) | JSON payload sent to GPT (audit trail) |
| ModelVersion | VARCHAR(20) | OpenAI model used (e.g. gpt-4o) |

## Churn Score Thresholds

| Score Range | Category | Recommended Action |
|---|---|---|
| 0.00 – 0.39 | Low | Standard nurture emails |
| 0.40 – 0.69 | Medium | Targeted discount offer |
| 0.70 – 1.00 | High | Immediate outreach + loyalty reward |

## Data Lineage

```
CSV Files (ADLS Gen2)
    → ADF Copy Activity
        → staging.SalesRaw / CustomerRaw / InventoryRaw
            → Stored Procedures (usp_LoadFactSales, etc.)
                → dwh.Fact* / dwh.Dim* tables
                    → dwh.vw_* views
                        → Power BI Dashboard
                            ← dwh.AIInsights (GPT-4 insights)
                            ← staging.ChurnScores (Python ML model)
```
