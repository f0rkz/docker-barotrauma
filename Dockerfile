FROM ghcr.io/f0rkz/docker-steamcmd:latest
USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -yq && \
    apt install -y --no-install-recommends \
        libssl-dev

COPY entrypoint.sh /home/steam/entrypoint.sh
RUN chmod +x /home/steam/entrypoint.sh
RUN chown steam:steam /home/steam/entrypoint.sh

USER steam

VOLUME [ "/data" ]

CMD /home/steam/entrypoint.sh
