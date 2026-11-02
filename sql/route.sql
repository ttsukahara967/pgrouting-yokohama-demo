-- Fastest route between two nodes, returned as one GeoJSON FeatureCollection.
--
-- pgr_dijkstra edges SQL must expose id, source, target, cost, reverse_cost.
-- Using cost_s / reverse_cost_s (seconds) makes this a travel-time route,
-- not a shortest-distance one. directed := true is required for one-way
-- streets to be honored (negative reverse_cost = no travel against the way).
WITH path AS (
  SELECT seq, node, edge, cost
  FROM pgr_dijkstra(
    'SELECT gid AS id, source, target, cost_s AS cost, reverse_cost_s AS reverse_cost FROM ways',
    %(source)s::bigint, %(target)s::bigint,
    directed := true
  )
  WHERE edge <> -1  -- last row is the target node itself
), segments AS (
  SELECT
    p.seq,
    -- Flip edges walked against their drawing direction so the line is continuous.
    CASE WHEN p.node = w.source THEN w.the_geom ELSE ST_Reverse(w.the_geom) END AS geom,
    w.length_m,
    p.cost AS seconds,
    w.name
  FROM path p
  JOIN ways w ON w.gid = p.edge
)
SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', COALESCE(json_agg(json_build_object(
    'type', 'Feature',
    'geometry', ST_AsGeoJSON(geom, 6)::json,
    'properties', json_build_object('seq', seq, 'length_m', round(length_m::numeric, 1),
                                    'seconds', round(seconds::numeric, 1), 'name', name)
  ) ORDER BY seq), '[]'::json),
  'properties', json_build_object(
    'length_m', COALESCE(sum(length_m), 0),
    'seconds', COALESCE(sum(seconds), 0),
    'edges', count(*)
  )
) AS geojson
FROM segments;
