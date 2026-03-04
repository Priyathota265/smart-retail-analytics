"""
============================================================
FILE: churn_model.py
PROJECT: Smart Retail Analytics Platform
DESCRIPTION: Customer churn prediction using Random Forest.
             Reads features from SQL, scores each customer,
             writes results back to staging.ChurnScores.
AUTHOR: Priyadarshini Thota
============================================================
"""

import os
import pandas as pd
import numpy as np
import pyodbc
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score, classification_report
from sklearn.preprocessing import StandardScaler
import joblib
import logging
from datetime import date

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

SQL_SERVER   = os.environ.get("SQL_SERVER",   "retailedge-sql.database.windows.net")
SQL_DATABASE = os.environ.get("SQL_DATABASE", "RetailEdgeDW")
SQL_USERNAME = os.environ.get("SQL_USERNAME", "")
SQL_PASSWORD = os.environ.get("SQL_PASSWORD", "")   # Stored in Azure Key Vault
MODEL_PATH   = "churn_model.pkl"
SCALER_PATH  = "churn_scaler.pkl"


# ─────────────────────────────────────────
# DATABASE CONNECTION
# ─────────────────────────────────────────
def get_connection():
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};"
        f"UID={SQL_USERNAME};PWD={SQL_PASSWORD};"
        "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    )
    return pyodbc.connect(conn_str)


# ─────────────────────────────────────────
# LOAD FEATURE DATA FROM SQL
# ─────────────────────────────────────────
def load_features(conn) -> pd.DataFrame:
    """Pull customer activity features from DW for scoring."""
    query = """
        SELECT
            c.CustomerID,
            ca.TotalOrders,
            ca.TotalSpend,
            ca.AvgOrderValue,
            ca.DaysSinceLastPurchase,
            ca.UniqueCategories,
            ca.SupportTickets,
            -- Derived features
            DATEDIFF(MONTH, c.JoinDate, GETDATE()) AS TenureMonths,
            CASE c.Segment
                WHEN 'Premium' THEN 3
                WHEN 'Regular' THEN 2
                ELSE 1
            END AS SegmentScore,
            -- Label: churned if no purchase in 90+ days (for training only)
            CASE WHEN ca.DaysSinceLastPurchase >= 90 THEN 1 ELSE 0 END AS ChurnLabel
        FROM dwh.DimCustomer c
        JOIN dwh.FactCustomerActivity ca ON c.CustomerKey = ca.CustomerKey
        WHERE c.IsActive = 1
    """
    df = pd.read_sql(query, conn)
    log.info(f"Loaded {len(df)} customer records for scoring.")
    return df


# ─────────────────────────────────────────
# FEATURE ENGINEERING
# ─────────────────────────────────────────
FEATURE_COLS = [
    "TotalOrders",
    "TotalSpend",
    "AvgOrderValue",
    "DaysSinceLastPurchase",
    "UniqueCategories",
    "SupportTickets",
    "TenureMonths",
    "SegmentScore",
]

def prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    """Clean and engineer features."""
    df = df.copy()
    df[FEATURE_COLS] = df[FEATURE_COLS].fillna(0)

    # Clip outliers (cap at 99th percentile)
    for col in ["TotalSpend", "AvgOrderValue", "DaysSinceLastPurchase"]:
        upper = df[col].quantile(0.99)
        df[col] = df[col].clip(upper=upper)

    # Log-transform skewed features
    df["LogTotalSpend"]   = np.log1p(df["TotalSpend"])
    df["LogAvgOrderValue"] = np.log1p(df["AvgOrderValue"])

    return df


# ─────────────────────────────────────────
# TRAIN MODEL (run once, then load saved)
# ─────────────────────────────────────────
EXTENDED_FEATURES = FEATURE_COLS + ["LogTotalSpend", "LogAvgOrderValue"]

def train_model(df: pd.DataFrame):
    """Train Random Forest churn classifier."""
    df = prepare_features(df)
    X = df[EXTENDED_FEATURES]
    y = df["ChurnLabel"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    scaler = StandardScaler()
    X_train_sc = scaler.fit_transform(X_train)
    X_test_sc  = scaler.transform(X_test)

    model = RandomForestClassifier(
        n_estimators=300,
        max_depth=8,
        min_samples_leaf=10,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_train_sc, y_train)

    # Evaluation
    y_prob = model.predict_proba(X_test_sc)[:, 1]
    auc    = roc_auc_score(y_test, y_prob)
    log.info(f"Model AUC: {auc:.4f}")
    log.info("\n" + classification_report(y_test, model.predict(X_test_sc)))

    # Feature importance
    fi = pd.DataFrame({
        "Feature": EXTENDED_FEATURES,
        "Importance": model.feature_importances_
    }).sort_values("Importance", ascending=False)
    log.info(f"\nFeature Importances:\n{fi.to_string(index=False)}")

    # Save model
    joblib.dump(model,  MODEL_PATH)
    joblib.dump(scaler, SCALER_PATH)
    log.info(f"Model saved → {MODEL_PATH}")

    return model, scaler


# ─────────────────────────────────────────
# SCORE ALL CUSTOMERS
# ─────────────────────────────────────────
def score_customers(df: pd.DataFrame, model, scaler) -> pd.DataFrame:
    """Generate churn probability for every active customer."""
    df_feat = prepare_features(df)
    X = df_feat[EXTENDED_FEATURES]
    X_scaled = scaler.transform(X)

    df["ChurnProbability"] = model.predict_proba(X_scaled)[:, 1].round(4)
    df["ScoredDate"]       = date.today().isoformat()

    log.info(f"Scored {len(df)} customers.")
    log.info(df["ChurnProbability"].describe().to_string())
    return df[["CustomerID", "ChurnProbability", "ScoredDate"]]


# ─────────────────────────────────────────
# WRITE SCORES BACK TO SQL
# ─────────────────────────────────────────
def write_scores(scores: pd.DataFrame, conn):
    """Write scored results to staging.ChurnScores for the SP to apply."""
    cursor = conn.cursor()

    # Truncate & reload
    cursor.execute("IF OBJECT_ID('staging.ChurnScores') IS NOT NULL TRUNCATE TABLE staging.ChurnScores")

    # Bulk insert
    rows = [tuple(r) for r in scores.itertuples(index=False)]
    cursor.executemany(
        "INSERT INTO staging.ChurnScores (CustomerID, ChurnProbability, ScoredDate) VALUES (?,?,?)",
        rows
    )
    conn.commit()
    log.info(f"Wrote {len(rows)} churn scores to staging.ChurnScores")

    # Call SP to apply scores to DimCustomer
    cursor.execute("EXEC dwh.usp_ApplyChurnScores")
    conn.commit()
    log.info("usp_ApplyChurnScores executed successfully.")
    cursor.close()


# ─────────────────────────────────────────
# SAVE SAMPLE OUTPUT (for GitHub preview)
# ─────────────────────────────────────────
def save_sample_output(scores: pd.DataFrame):
    sample = scores.head(20).copy()
    sample["ChurnRiskCategory"] = sample["ChurnProbability"].apply(
        lambda p: "High" if p >= 0.70 else ("Medium" if p >= 0.40 else "Low")
    )
    sample.to_csv("model_output_sample.csv", index=False)
    log.info("Sample output saved → model_output_sample.csv")


# ─────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────
def main():
    log.info("=== Churn Model Pipeline Starting ===")
    conn = get_connection()

    df = load_features(conn)

    # Load or train model
    if os.path.exists(MODEL_PATH) and os.path.exists(SCALER_PATH):
        log.info("Loading existing model...")
        model  = joblib.load(MODEL_PATH)
        scaler = joblib.load(SCALER_PATH)
    else:
        log.info("Training new model...")
        model, scaler = train_model(df)

    # Score
    scores = score_customers(df, model, scaler)

    # Write back to SQL
    write_scores(scores, conn)

    # Save sample for GitHub
    save_sample_output(scores)

    conn.close()
    log.info("=== Churn Model Pipeline Complete ===")


if __name__ == "__main__":
    main()
