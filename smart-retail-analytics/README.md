# 🛒 Smart Retail Analytics Platform
### End-to-End Data Engineering & AI-Powered BI Solution

![Azure](https://img.shields.io/badge/Azure-Data%20Factory%20%7C%20Synapse%20%7C%20Key%20Vault-0078D4?style=for-the-badge&logo=microsoftazure)
![SQL](https://img.shields.io/badge/SQL-Server%20%7C%20Stored%20Procs%20%7C%20Optimization-CC2927?style=for-the-badge&logo=microsoftsqlserver)
![Python](https://img.shields.io/badge/Python-pandas%20%7C%20OpenAI%20%7C%20scikit--learn-3776AB?style=for-the-badge&logo=python)
![Power BI](https://img.shields.io/badge/Power%20BI-DAX%20%7C%20RLS%20%7C%20KPI%20Dashboards-F2C811?style=for-the-badge&logo=powerbi)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions)

---

## 📌 Project Overview

A **production-grade, end-to-end retail analytics platform** that ingests raw sales, inventory, and customer data → transforms it through a cloud data pipeline → enriches it with **AI-generated insights** → and surfaces actionable KPIs in **Power BI dashboards**.

Built to demonstrate real-world data engineering skills across the full modern data stack.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                                  │
│  CSV / Excel / REST APIs / SQL Server (On-Prem)                     │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   AZURE DATA FACTORY (Ingestion)                     │
│  • Parameterized pipelines  • Trigger scheduling  • Error alerts    │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│               AZURE DATA LAKE STORAGE Gen2 (Raw Zone)                │
│  • Bronze / Silver / Gold medallion architecture                    │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│         AZURE SYNAPSE ANALYTICS + SQL TRANSFORMATIONS               │
│  • Stored Procedures  • Star Schema  • Data Quality Checks          │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│           PYTHON AI ENRICHMENT LAYER (Azure Functions)              │
│  • Churn Prediction (scikit-learn)  • GPT-4 Sales Commentary        │
│  • Anomaly Detection  • Forecast Generation                         │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  POWER BI SERVICE (Reporting Layer)                  │
│  • Executive KPI Dashboard  • Store Performance  • AI Insights Tab  │
│  • Row-Level Security (RLS)  • Scheduled Refresh  • Mobile Layout   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
smart-retail-analytics/
├── sql/
│   ├── 01_create_schema.sql
│   ├── 02_create_tables.sql
│   ├── 03_stored_procedures.sql
│   ├── 04_data_quality_checks.sql
│   └── 05_analytical_queries.sql
├── python/
│   ├── ingestion/adf_trigger.py
│   ├── transformation/transform_silver.py
│   ├── ai/churn_model.py
│   ├── ai/anomaly_detection.py
│   ├── ai/ai_commentary.py
│   └── requirements.txt
├── powerbi/
│   ├── dashboard_design.md
│   ├── dax_measures.md
│   └── rls_setup.md
├── azure/
│   ├── adf_pipeline.json
│   ├── synapse_config.json
│   └── infrastructure_notes.md
├── data_samples/
│   └── sample_sales_data.csv
├── .github/workflows/
│   └── ci_cd_pipeline.yml
├── docs/
│   └── project_walkthrough.md
└── README.md
```

---

## 🔧 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Cloud** | Azure Data Factory, Synapse Analytics, ADLS Gen2, Key Vault, Azure Functions |
| **Database** | Azure SQL / SQL Server — Stored Procedures, Views, Star Schema |
| **ETL** | Azure Data Factory, Python (pandas, NumPy) |
| **AI / ML** | scikit-learn (Churn), OpenAI GPT-4 (Commentary), Isolation Forest (Anomaly) |
| **BI** | Power BI — DAX, Power Query, RLS, KPI Dashboards, Paginated Reports |
| **CI/CD** | GitHub Actions |
| **Security** | Azure Key Vault, Row-Level Security (Power BI) |

---

## 🚀 Key Features

### ⚙️ Data Pipeline
- **Medallion Architecture** (Bronze → Silver → Gold) on Azure Data Lake Gen2
- Parameterized ADF pipelines with retry logic and email alerting
- Incremental loads using watermark pattern for large dataset efficiency

### 🧠 AI Layer
- **Customer Churn Prediction** — Random Forest on RFM features; churn probability scores written back to SQL
- **Sales Anomaly Detection** — Isolation Forest flags unusual revenue spikes/drops, surfaced in Power BI
- **AI-Generated Commentary** — GPT-4 writes natural language weekly KPI summaries rendered as Power BI text cards

### 📊 Power BI Dashboard (4 Pages)
1. **Executive Summary** — Revenue, Profit Margin, YoY Growth, Forecast vs Actuals
2. **Store Performance** — Regional heatmaps, store-level drill-through, inventory turns
3. **Customer Intelligence** — Churn risk segmentation, LTV cohorts, retention trends
4. **AI Insights** — Anomaly alerts + GPT-4 auto-commentary

### 🔐 Security
- Azure Key Vault — zero hardcoded credentials
- Power BI RLS by region/manager role
- Data validation stored procedures with full audit logging

---

## 📈 Business Impact

| Metric | Before | After |
|--------|--------|-------|
| Report generation time | 4 hours manual | 15 min automated |
| Data freshness | Daily (T+1) | Hourly refresh |
| Churn model | None | 84% F1 score |
| Exec reporting effort | 8 hrs/week | 1 hr/week |
| Anomalies caught proactively | 0 | 12–15/month |

---

## ⚡ Quick Start

```bash
# 1. Clone
git clone https://github.com/priyadarshinithota/smart-retail-analytics.git
cd smart-retail-analytics

# 2. Install Python dependencies
pip install -r python/requirements.txt

# 3. Set environment variables (use Azure Key Vault in production)
export AZURE_SQL_CONNECTION="your_connection_string"
export OPENAI_API_KEY="your_openai_key"
export ADF_SUBSCRIPTION_ID="your_subscription_id"

# 4. Initialize DB — run SQL scripts in order (01 → 05) in SSMS or Azure Data Studio

# 5. Run pipeline
python python/ingestion/adf_trigger.py
python python/ai/churn_model.py
python python/ai/anomaly_detection.py
python python/ai/ai_commentary.py

# 6. Open Power BI Desktop, connect to Azure SQL, publish to Power BI Service
```

---

## 🤝 Author

**Priyadarshini Thota** — Data Engineer & BI Developer
6+ years across Azure, Snowflake, Power BI, Python, and SQL.

📧 priyadarshinithota994@gmail.com | 🔗 [LinkedIn](https://linkedin.com/in/priyadarshinithota)

---
MIT License
