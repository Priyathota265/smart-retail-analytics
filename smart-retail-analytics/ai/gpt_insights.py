"""
============================================================
FILE: gpt_insights.py
PROJECT: Smart Retail Analytics Platform
DESCRIPTION: Queries live KPIs from SQL, sends structured
             prompt to OpenAI GPT-4, and saves plain-English
             insights to dwh.AIInsights for Power BI display.
AUTHOR: Priyadarshini Thota
============================================================
"""

import os
import json
import pyodbc
import openai
import logging
from datetime import date, datetime

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

# ─────────────────────────────────────────
# CONFIG (secrets from Azure Key Vault / env vars)
# ─────────────────────────────────────────
SQL_SERVER      = os.environ.get("SQL_SERVER",   "retailedge-sql.database.windows.net")
SQL_DATABASE    = os.environ.get("SQL_DATABASE", "RetailEdgeDW")
SQL_USERNAME    = os.environ.get("SQL_USERNAME", "")
SQL_PASSWORD    = os.environ.get("SQL_PASSWORD", "")
OPENAI_API_KEY  = os.environ.get("OPENAI_API_KEY", "")
GPT_MODEL       = "gpt-4o"

openai.api_key = OPENAI_API_KEY


# ─────────────────────────────────────────
# DB CONNECTION
# ─────────────────────────────────────────
def get_connection():
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};"
        f"UID={SQL_USERNAME};PWD={SQL_PASSWORD};"
        "Encrypt=yes;TrustServerCertificate=no;"
    )
    return pyodbc.connect(conn_str)


# ─────────────────────────────────────────
# PULL KPI DATA FROM SQL
# ─────────────────────────────────────────
def fetch_kpis(conn) -> dict:
    """Fetch current KPIs from reporting views."""
    kpis = {}

    # Overall KPI Summary
    row = conn.execute("SELECT * FROM dwh.vw_KPISummary").fetchone()
    if row:
        cols = [d[0] for d in conn.execute("SELECT * FROM dwh.vw_KPISummary").description]
        kpis["summary"] = dict(zip(cols, row))

    # Top 5 products by net sales this month
    top_products = conn.execute("""
        SELECT TOP 5 Category, SubCategory,
               SUM(NetSales) AS NetSales,
               SUM(GrossProfit) AS GrossProfit,
               SUM(UnitsSold) AS UnitsSold
        FROM dwh.vw_SalesSummary
        WHERE Year = YEAR(GETDATE()) AND MonthNumber = MONTH(GETDATE())
        GROUP BY Category, SubCategory
        ORDER BY NetSales DESC
    """).fetchall()
    kpis["top_products"] = [
        {"category": r[0], "sub_category": r[1],
         "net_sales": float(r[2] or 0), "gross_profit": float(r[3] or 0),
         "units_sold": int(r[4] or 0)}
        for r in top_products
    ]

    # High churn customers count by region
    churn_by_region = conn.execute("""
        SELECT Region, COUNT(*) AS HighChurnCustomers,
               SUM(RevenueAtRisk) AS TotalAtRisk
        FROM dwh.vw_ChurnRiskDashboard
        WHERE ChurnRiskCategory = 'High'
        GROUP BY Region
        ORDER BY TotalAtRisk DESC
    """).fetchall()
    kpis["churn_by_region"] = [
        {"region": r[0], "customers": int(r[1]), "revenue_at_risk": float(r[2] or 0)}
        for r in churn_by_region
    ]

    # Inventory alerts
    inv_alerts = conn.execute("""
        SELECT TOP 5 ProductName, Category, StoreType,
               QuantityOnHand, DaysOfSupply, StockOutRisk
        FROM dwh.vw_InventoryIntelligence
        WHERE StockOutRisk IN ('High','Medium')
        ORDER BY DaysOfSupply ASC
    """).fetchall()
    kpis["inventory_alerts"] = [
        {"product": r[0], "category": r[1], "store_type": r[2],
         "qty_on_hand": int(r[3] or 0), "days_of_supply": int(r[4] or 0),
         "risk": r[5]}
        for r in inv_alerts
    ]

    log.info(f"KPIs fetched: {list(kpis.keys())}")
    return kpis


# ─────────────────────────────────────────
# BUILD GPT PROMPT
# ─────────────────────────────────────────
def build_prompt(kpis: dict, insight_area: str) -> str:
    """Construct a structured prompt for a given insight area."""
    today = date.today().strftime("%B %d, %Y")

    base = f"""
You are a senior retail data analyst generating concise, actionable business insights 
for executive dashboards. Today is {today}. Speak directly to business leaders.
Avoid jargon. Be specific with numbers. Recommend one clear action per insight.

Here is the latest data in JSON format:
{json.dumps(kpis, indent=2)}

"""

    prompts = {
        "Revenue": base + """
Generate a 3-sentence revenue insight covering:
1. How current month revenue is trending
2. Which product category is leading
3. One specific recommendation to grow revenue next month.
""",
        "Churn": base + """
Generate a 3-sentence customer churn insight covering:
1. The size of the at-risk customer base and revenue at stake
2. Which region has the highest churn exposure
3. One specific retention action to take immediately.
""",
        "Inventory": base + """
Generate a 3-sentence inventory insight covering:
1. Which products are at highest stockout risk
2. The financial implication of stockout vs overstock
3. One specific supply chain action recommended.
""",
        "Overall": base + """
Generate a concise 4-sentence executive summary covering:
revenue performance, customer retention risk, inventory health, 
and the single most important action the business should take this week.
""",
    }
    return prompts.get(insight_area, prompts["Overall"])


# ─────────────────────────────────────────
# CALL GPT-4
# ─────────────────────────────────────────
def generate_insight(kpis: dict, insight_area: str) -> str:
    """Call OpenAI GPT-4 and return the insight text."""
    prompt = build_prompt(kpis, insight_area)

    response = openai.chat.completions.create(
        model=GPT_MODEL,
        messages=[
            {"role": "system", "content": "You are a retail business intelligence analyst."},
            {"role": "user",   "content": prompt}
        ],
        temperature=0.4,
        max_tokens=300,
    )

    insight_text = response.choices[0].message.content.strip()
    log.info(f"[{insight_area}] GPT insight generated ({len(insight_text)} chars)")
    return insight_text


# ─────────────────────────────────────────
# SAVE INSIGHTS TO SQL
# ─────────────────────────────────────────
def save_insight(conn, insight_area: str, insight_text: str, kpis: dict):
    """Persist GPT insight to dwh.AIInsights for Power BI consumption."""
    conn.execute("""
        INSERT INTO dwh.AIInsights (InsightDate, InsightArea, InsightText, KPIContext, ModelVersion)
        VALUES (?, ?, ?, ?, ?)
    """, (
        date.today(),
        insight_area,
        insight_text,
        json.dumps(kpis),
        GPT_MODEL
    ))
    conn.commit()
    log.info(f"Saved insight [{insight_area}] to dwh.AIInsights")


# ─────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────
def main():
    log.info("=== GPT Insights Engine Starting ===")
    conn = get_connection()
    kpis = fetch_kpis(conn)

    areas = ["Revenue", "Churn", "Inventory", "Overall"]

    for area in areas:
        try:
            insight = generate_insight(kpis, area)
            save_insight(conn, area, insight, kpis)
            print(f"\n── {area} Insight ──\n{insight}\n")
        except Exception as e:
            log.error(f"Failed to generate [{area}] insight: {e}")

    conn.close()
    log.info("=== GPT Insights Engine Complete ===")


if __name__ == "__main__":
    main()
