#!/usr/bin/env bash
# One-shot import job. Idempotent: skips everything when the requested BBOX
# is already recorded in import_meta.
set -euo pipefail

: "${BBOX:?BBOX is required (min_lon,min_lat,max_lon,max_lat)}"
: "${OSM_PBF_URL:?OSM_PBF_URL is required}"

PBF=/data/$(basename "$OSM_PBF_URL")
EXTRACT=/data/extract.osm
# Car profile: decides which highway tags become edges and the default speed
# for each. Ours is a Japan-tuned copy of the bundled mapconfig_for_cars.xml.
MAPCONFIG=${MAPCONFIG:-/etc/osm2pgrouting/mapconfig_japan_cars.xml}

log() { echo "[importer] $*"; }

# The import is keyed by BBOX + mapconfig hash, so editing either re-imports.
IMPORT_KEY="$BBOX mapconfig:$(sha256sum "$MAPCONFIG" | cut -c1-12)"
# import_meta is absent before the first import; that query error is expected.
done_key=$(psql -qtAX -c "SELECT import_key FROM import_meta" 2>/dev/null || true)
if [[ "$done_key" == "$IMPORT_KEY" ]]; then
  log "Already imported ($IMPORT_KEY), skipping."
  exit 0
fi
log "Import needed (requested '$IMPORT_KEY', imported '${done_key:-none}')."

# 1. Download the regional extract once; later runs reuse the cached file.
if [[ ! -s "$PBF" ]]; then
  log "Downloading $OSM_PBF_URL (several hundred MB, first run only)..."
  curl -fL --retry 3 --progress-bar -o "$PBF.part" "$OSM_PBF_URL"
  mv "$PBF.part" "$PBF"
else
  log "Using cached $PBF."
fi

# 2. Clip to the BBOX and convert to OSM XML. osm2pgrouting cannot read PBF
#    and keeps the whole file in memory, so the clip keeps it small.
log "Clipping to BBOX with osmium..."
osmium extract --bbox "$BBOX" --strategy complete_ways --overwrite \
  -o "$EXTRACT" "$PBF"
ls -lh "$EXTRACT"

# 3. Load into ways / ways_vertices_pgr. --clean drops existing tables.
psql -qX -c "DROP TABLE IF EXISTS import_meta"
log "Running osm2pgrouting with $(basename "$MAPCONFIG")..."
osm2pgrouting \
  --file "$EXTRACT" \
  --conf "$MAPCONFIG" \
  --dbname "$PGDATABASE" --username "$PGUSER" --password "$PGPASSWORD" \
  --host "$PGHOST" --port "$PGPORT" \
  --clean

# 4. Indexes, reachable-network flag and the import marker.
log "Post-processing..."
psql -qX -v ON_ERROR_STOP=1 -v import_key="$IMPORT_KEY" -f /sql/post_import.sql

rm -f "$EXTRACT"
log "Import finished."
