# Smart Retail Analytics Platform

An end-to-end retail analytics platform that ingests raw retail data, transforms it through a dimensional data warehouse, and serves insights through interactive Power BI dashboards — plus ML-powered churn prediction and GPT-generated narrative insights.

![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![T-SQL](https://img.shields.io/badge/T--SQL-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![Azure Data Factory](https://img.shields.io/badge/Azure%20Data%20Factory-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![scikit-learn](https://img.shields.io/badge/scikit--learn-F7931E?style=flat&logo=scikitlearn&logoColor=white)

## What it does

- **Ingests** retail CSV extracts (sales, customers, inventory) from Azure Data Lake Storage Gen2 via the Azure Data Factory master pipeline `PL_RetailEdge_Master_Ingestion`
- **Transforms** raw data into the `RetailEdgeDW` star-schema warehouse using stored procedures and reporting views
- **Visualizes** KPIs across 4 Power BI dashboard pages (Executive Overview, Customer Churn Analysis, Inventory Intelligence, AI Insights) with hand-written DAX measures and row-level security
- **Predicts** customer churn with a Random Forest model, writing per-customer scores back to `staging.ChurnScores`
- **Narrates** KPI movements in plain English using GPT-4o, persisting insights plus the full KPI JSON context to `dwh.AIInsights` for auditability

## Architecture

```
CSV Files (ADLS Gen2)
  → ADF Copy Activities (PL_RetailEdge_Master_Ingestion)
    → staging.SalesRaw / CustomerRaw / InventoryRaw
      → Stored Procedures (usp_LoadFactSales, …)
        → dwh.Dim* / dwh.Fact*  (star schema)
          → dwh.vw_* reporting views
            → Power BI dashboards
              ← dwh.AIInsights   (GPT-4o narrative insights)
              ← staging.ChurnScores (Random Forest churn model)
```

## Project structure

```
smart-retail-analytics/
├── azure/
│   └── adf_pipeline.json        # ADF master pipeline: ADLS → validate → SQL DW → trigger AI scoring
├── sql/                         # Warehouse DDL + ETL logic — run in numbered order
│   ├── 01_create_schema.sql     # Star schema: DimDate, DimCustomer, FactSales, …
│   ├── 02_stored_procedures.sql # ETL stored procedures (staging → dwh)
│   ├── 03_views.sql             # vw_* reporting views for Power BI
│   └── 04_sample_data.sql       # Sample data for a local setup
├── ai/
│   ├── churn_model.py           # Random Forest churn prediction → staging.ChurnScores
│   ├── gpt_insights.py          # GPT-4o narrative insights → dwh.AIInsights
│   ├── model_output_sample.csv  # Sample scoring output
│   └── requirements.txt
├── powerbi/
│   └── dax_measures.md          # DAX measures for all 4 dashboard pages + RLS patterns
├── data/                        # Sample source CSVs (customers, sales)
└── docs/
    └── data_dictionary.md       # Column definitions, churn thresholds, lineage
```

## Getting started

1. **Create the warehouse** — run `sql/01_create_schema.sql` through `sql/04_sample_data.sql` in order on SQL Server or Azure SQL.
2. **Deploy the pipeline** — import `azure/adf_pipeline.json` into Azure Data Factory and point the ADLS Gen2 and Azure SQL linked services at your own resources.
3. **Score churn** — `pip install -r ai/requirements.txt`, set `SQL_SERVER`, `SQL_DATABASE`, `SQL_USERNAME`, `SQL_PASSWORD`, then run `ai/churn_model.py`.
4. **Generate narratives** — set `OPENAI_API_KEY` (same SQL env vars) and run `ai/gpt_insights.py`.
5. **Build dashboards** — connect Power BI Desktop to the warehouse and paste the measures from `powerbi/dax_measures.md`.

## Data model highlights

| Table | Purpose |
|---|---|
| `dwh.DimCustomer` | Customer dimension with `ChurnRiskScore` (0.0–1.0) and `ChurnRiskCategory` (Low / Medium / High) |
| `dwh.FactSales` | Sales facts with computed `GrossSales`, `NetSales`, `GrossProfit`, and `ReturnFlag` exclusions |
| `dwh.AIInsights` | GPT-generated narratives with the KPI JSON context preserved for audit |

Churn score thresholds and recommended actions (nurture → discount → outreach) are documented in `docs/data_dictionary.md`.

## Tech stack

Python (pandas, scikit-learn, pyodbc, OpenAI) · T-SQL (star schema, stored procedures, views) · Azure Data Factory · Azure SQL / SQL Server · ADLS Gen2 · Power BI (DAX, RLS)
