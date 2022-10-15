FROM ghcr.io/f0rkz/docker-steamcmd:latest
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -yq && \
    apt install -y --no-install-recommends \
        libssl-dev

USER steam

VOLUME [ "/data" ]

COPY entrypoint.sh /home/steam/entrypoint.sh
RUN chmod +x /home/steam/entrypoint.sh

CMD /home/steam/entrypoint.sh
