"""
services/distance_service.py
-----------------------------
Calculates shortest-path distance (km) between two railway stations
using the All India Railway graph, and estimates arrival time
based on a fixed average speed.
"""

import re
import math
import pandas as pd
import networkx as nx
import joblib
from datetime import datetime, timedelta

AVERAGE_SPEED_KMPH = 20  # hardcoded as per requirement


def load_graph(graph_path: str):
    """Load the railway network graph from a .pkl file."""
    print(f"  Loading graph from {graph_path}...")
    G = joblib.load(graph_path)
    print(f"  Graph loaded: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")
    return G


def build_wc_station_map(fmm_path: str) -> dict:
    """Build a mapping from work_center_id (org_slno) -> station code (station_name)."""
    fmm = pd.read_csv(fmm_path)
    return dict(zip(fmm["org_slno"], fmm["station_name"]))


# Suffix patterns to strip from messy yard codes
_STRIP_SUFFIXES = re.compile(
    r"(YD|DEP|EMP|OUT|BIA|EX YD|EX|_BH|_GM|ICD|AYD|REPYD|SYD|SLYD|SL)$",
    re.IGNORECASE,
)


def resolve_station(raw: str, G) -> str | None:
    """
    Try to find `raw` as a node in graph G.
    Falls back through several cleaning strategies if direct match fails.
    Returns matched node string, or None if unresolvable.
    """
    if not isinstance(raw, str) or not raw.strip():
        return None

    raw = raw.strip()

    # 1. Direct match
    if raw in G.nodes:
        return raw

    # 2. Slash split — try each part right-to-left (e.g. WDD/UDL → UDL)
    if "/" in raw:
        for part in reversed(raw.split("/")):
            part = part.strip()
            if part in G.nodes:
                return part

    # 3. Strip known suffixes iteratively
    candidate = re.sub(r"[\s_/]", "", raw).upper()
    for _ in range(4):
        stripped = _STRIP_SUFFIXES.sub("", candidate).strip()
        if stripped == candidate:
            break
        candidate = stripped
        if candidate in G.nodes:
            return candidate

    # 4. Underscore base (e.g. PPY_BIA → PPY)
    base = raw.split("_")[0].strip()
    if base in G.nodes:
        return base

    # 5. Trim trailing characters one by one
    candidate = re.sub(r"[^A-Z]", "", raw.upper())
    while len(candidate) > 2:
        candidate = candidate[:-1]
        if candidate in G.nodes:
            return candidate

    return None


def get_distance_km(src: str, tgt: str, G) -> float | None:
    """
    Returns shortest path distance in km between src and tgt nodes.
    Returns None if either node is missing or no path exists.
    """
    if not src or not tgt:
        return None
    if src not in G.nodes or tgt not in G.nodes:
        return None
    if not nx.has_path(G, src, tgt):
        return None
    return round(
        nx.shortest_path_length(G, source=src, target=tgt, weight="SEGMENTDIST"), 2
    )


def estimate_arrival(last_updated: str, distance_km: float) -> str | None:
    """
    Estimates arrival datetime given:
      - last_updated : last known timestamp of the wagon (string)
      - distance_km  : distance to travel in km
    Uses AVERAGE_SPEED_KMPH to compute travel hours.
    Returns estimated arrival as a formatted datetime string.
    """
    if distance_km is None or math.isnan(distance_km):
        return None
    try:
        base_time = pd.to_datetime(last_updated)
        travel_hours = distance_km / AVERAGE_SPEED_KMPH
        arrival = base_time + timedelta(hours=travel_hours)
        return arrival.strftime("%Y-%m-%d %H:%M")
    except Exception:
        return None


def add_distance_and_eta(df: pd.DataFrame, graph_path: str, fmm_path: str) -> pd.DataFrame:
    """
    Main function to call from main.py.
    Adds three columns to df:
      - Distance (km)
      - Expected Travel Time (hrs)
      - Expected Arrival
    """
    G = load_graph(graph_path)
    wc_to_stn = build_wc_station_map(fmm_path)

    # Resolve ROH depot → station code
    df["_depot_stn"] = df["ROH Depot"].map(wc_to_stn)

    # Resolve Current Station (already clean but run through resolver for safety)
    df["_curr_stn"] = df["Current Station"].apply(lambda x: resolve_station(x, G))

    # Calculate distance
    df["Distance (km)"] = df.apply(
        lambda r: get_distance_km(r["_curr_stn"], r["_depot_stn"], G), axis=1
    )

    # Calculate expected travel time in hours
    df["Expected Travel Time (hrs)"] = df["Distance (km)"].apply(
        lambda d: round(d / AVERAGE_SPEED_KMPH, 2) if pd.notna(d) else None
    )

    # Calculate expected arrival datetime
    df["Expected Arrival"] = df.apply(
        lambda r: estimate_arrival(r["Last Updated"], r["Distance (km)"]), axis=1
    )

    # Drop internal helper columns
    df.drop(columns=["_depot_stn", "_curr_stn"], inplace=True)

    return df
