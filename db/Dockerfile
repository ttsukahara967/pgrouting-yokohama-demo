# The official postgis/postgis and pgrouting/pgrouting images are amd64-only,
# so build from postgres (multi-arch) and add the extensions from the PGDG apt
# repository that the base image already has configured. Runs natively on
# Apple Silicon (arm64) and on amd64.
FROM postgres:17.6-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      postgresql-17-postgis-3 \
      postgresql-17-pgrouting \
 && rm -rf /var/lib/apt/lists/*

COPY init.sql /docker-entrypoint-initdb.d/10-extensions.sql
