FROM clockworklabs/spacetimedb:latest

ENV SPACETIME_DATA_DIR=/var/lib/spacetimedb
ENV SPACETIME_LISTEN_ADDR=0.0.0.0:3000
ENV SPACETIME_DB_NAME=vg-server

WORKDIR /app

COPY spacetimedb /app/spacetimedb
COPY docker/entrypoint.sh /app/docker/entrypoint.sh

RUN chmod +x /app/docker/entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/app/docker/entrypoint.sh"]
