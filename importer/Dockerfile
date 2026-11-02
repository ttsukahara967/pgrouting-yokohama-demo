# osm2pgrouting and osmium-tool come from Debian's own repository (multi-arch).
FROM debian:bookworm-20251020-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      osm2pgrouting \
      osmium-tool \
      postgresql-client \
      curl \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY import.sh /usr/local/bin/import.sh
COPY mapconfig_japan_cars.xml /etc/osm2pgrouting/mapconfig_japan_cars.xml
RUN chmod +x /usr/local/bin/import.sh

CMD ["/usr/local/bin/import.sh"]
