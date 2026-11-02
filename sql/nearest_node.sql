-- Nearest routable intersection to a clicked point.
-- ST_MakePoint takes (lon, lat) — x first. Mixing up the order is the most
-- common mistake and silently lands the point in the ocean.
-- <-> on SRID 4326 compares degrees, which is fine for picking the nearest
-- candidate at this scale; the reported distance uses geography (meters).
SELECT
  id,
  ST_X(the_geom) AS lon,
  ST_Y(the_geom) AS lat,
  ST_Distance(the_geom::geography, ST_SetSRID(ST_MakePoint(%(lon)s, %(lat)s), 4326)::geography) AS snap_m
FROM ways_vertices_pgr
WHERE in_main
ORDER BY the_geom <-> ST_SetSRID(ST_MakePoint(%(lon)s, %(lat)s), 4326)
LIMIT 1;
