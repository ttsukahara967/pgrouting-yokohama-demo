-- Runs after osm2pgrouting. Tables it creates (all geometry in SRID 4326):
--   ways               edges: gid, source, target, length_m,
--                      cost_s / reverse_cost_s (seconds, see below), the_geom
--   ways_vertices_pgr  nodes (intersections): id, the_geom
--
-- cost_s         = travel time along the way's drawing direction
--                  (length_m / maxspeed_forward).
-- reverse_cost_s = travel time against it. For a one-way street this is
--                  negative, and pgr_dijkstra(directed := true) treats a
--                  negative cost as "this direction does not exist".

-- Mark nodes in the largest strongly connected component (every node in it
-- can reach every other node respecting one-way rules). Snapping clicks only
-- to these nodes means a route always exists; otherwise a click could snap to
-- a dead-end parking aisle or a road cut off by the BBOX edge.
ALTER TABLE ways_vertices_pgr ADD COLUMN IF NOT EXISTS in_main boolean NOT NULL DEFAULT false;

WITH comp AS (
  SELECT component, node
  FROM pgr_strongComponents(
    'SELECT gid AS id, source, target, cost_s AS cost, reverse_cost_s AS reverse_cost FROM ways'
  )
), biggest AS (
  SELECT component FROM comp GROUP BY component ORDER BY count(*) DESC LIMIT 1
)
UPDATE ways_vertices_pgr v
SET in_main = true
FROM comp JOIN biggest USING (component)
WHERE comp.node = v.id;

-- KNN (<->) lookup of the nearest routable node uses this partial index.
CREATE INDEX IF NOT EXISTS ways_vertices_main_geom_idx
  ON ways_vertices_pgr USING gist (the_geom) WHERE in_main;
CREATE INDEX IF NOT EXISTS ways_source_idx ON ways (source);
CREATE INDEX IF NOT EXISTS ways_target_idx ON ways (target);

ANALYZE ways;
ANALYZE ways_vertices_pgr;

-- Written last, so a failed import is retried on the next start.
CREATE TABLE import_meta (import_key text NOT NULL, imported_at timestamptz NOT NULL DEFAULT now());
INSERT INTO import_meta (import_key) VALUES (:'import_key');

SELECT
  (SELECT count(*) FROM ways) AS edges,
  (SELECT count(*) FROM ways_vertices_pgr) AS nodes,
  (SELECT count(*) FROM ways_vertices_pgr WHERE in_main) AS routable_nodes;
