import os
import pandas as pd
from datetime import datetime
from services.db_service import get_connection
from services.distance_service import add_distance_and_eta

# ── Paths to supporting data files (update if needed) ────────────────────────
GRAPH_PATH = "data/ALL_INDIA_GRAPH_STATION.pkl"
FMM_PATH   = "data/fmm_org_m.csv"
# ─────────────────────────────────────────────────────────────────────────────

def load_query(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def main():
    conn = get_connection()
    query = load_query("queries/final_report.sql")
    df = pd.read_sql(query, conn)
    conn.close()

    print(f"Fetched {len(df)} rows from database.")

    # Add distance and expected arrival columns
    print("Calculating distances and expected arrivals...")
    df = add_distance_and_eta(df, GRAPH_PATH, FMM_PATH)

    # Summary
    calculated = df["Distance (km)"].notna().sum()
    missing    = df["Distance (km)"].isna().sum()
    print(f"  Distance calculated : {calculated} rows")
    print(f"  Distance missing    : {missing} rows")

    os.makedirs("outputs/csv", exist_ok=True)
    timestamp   = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"outputs/csv/NKJRH_ROH_{timestamp}.csv"
    df.to_csv(output_file, index=False)

    print(f"Saved → {output_file}")

if __name__ == "__main__":
    main()
