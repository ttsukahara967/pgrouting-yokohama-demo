"""Minimal routing API over the pgRouting tables built by the importer."""

import logging
import os
from pathlib import Path

import psycopg
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

DATABASE_URL = os.environ["DATABASE_URL"]
BBOX = [float(v) for v in os.environ["BBOX"].split(",")]  # min_lon,min_lat,max_lon,max_lat
SQL_DIR = Path(__file__).parent / "sql"
NEAREST_SQL = (SQL_DIR / "nearest_node.sql").read_text()
ROUTE_SQL = (SQL_DIR / "route.sql").read_text()

log = logging.getLogger("uvicorn.error")
app = FastAPI(title="pgRouting Yokohama demo")


@app.on_event("startup")
def announce() -> None:
    log.info("Ready: open %s", os.environ.get("PUBLIC_URL", "http://localhost:8000"))


def in_bbox(lon: float, lat: float) -> bool:
    return BBOX[0] <= lon <= BBOX[2] and BBOX[1] <= lat <= BBOX[3]


def nearest(cur: psycopg.Cursor, lon: float, lat: float) -> dict:
    cur.execute(NEAREST_SQL, {"lon": lon, "lat": lat})
    node_id, nlon, nlat, snap_m = cur.fetchone()
    return {"id": node_id, "lon": nlon, "lat": nlat, "snap_m": round(snap_m, 1)}


@app.get("/api/health")
def health() -> dict:
    with psycopg.connect(DATABASE_URL) as conn:
        conn.execute("SELECT 1 FROM import_meta")
    return {"status": "ok"}


@app.get("/api/config")
def config() -> dict:
    return {"bbox": BBOX}


@app.get("/api/route")
def route(
    from_lat: float = Query(...),
    from_lon: float = Query(...),
    to_lat: float = Query(...),
    to_lon: float = Query(...),
) -> dict:
    for name, lon, lat in (("from", from_lon, from_lat), ("to", to_lon, to_lat)):
        if not in_bbox(lon, lat):
            raise HTTPException(400, f"'{name}' point is outside the imported area")

    with psycopg.connect(DATABASE_URL) as conn, conn.cursor() as cur:
        src = nearest(cur, from_lon, from_lat)
        dst = nearest(cur, to_lon, to_lat)
        if src["id"] == dst["id"]:
            raise HTTPException(400, "Start and destination snap to the same intersection")
        cur.execute(ROUTE_SQL, {"source": src["id"], "target": dst["id"]})
        geojson = cur.fetchone()[0]

    if not geojson["features"]:
        raise HTTPException(404, "No route found")
    geojson["properties"]["from_node"] = src
    geojson["properties"]["to_node"] = dst
    return geojson


@app.get("/")
def index() -> FileResponse:
    return FileResponse(Path(__file__).parent / "static" / "index.html")


app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")
