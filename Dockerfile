# syntax=docker/dockerfile:1

FROM ghcr.io/f0rkz/docker-steamcmd:2

LABEL org.opencontainers.image.title="Docker Barotrauma" \
      org.opencontainers.image.description="Barotrauma dedicated server container" \
      org.opencontainers.image.source="https://github.com/f0rkz/docker-barotrauma" \
      org.opencontainers.image.licenses="MIT"

USER root

# Runtime package revisions follow the pinned SteamCMD base image.
# hadolint ignore=DL3008
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        gettext-base \
        expect \
        libgssapi-krb5-2 \
        libicu76 \
        libssl3t64 \
        libstdc++6 \
        xmlstarlet \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && install --directory --owner=steam --group=steam \
        /config/barotrauma \
        /data/barotrauma \
        /data/state \
        /opt/barotrauma

COPY --chown=steam:steam serversettings.xml.tmpl /opt/barotrauma/serversettings.xml.tmpl
COPY --chown=steam:steam entrypoint.sh /usr/local/bin/barotrauma-entrypoint
COPY --chown=steam:steam console.exp /usr/local/bin/barotrauma-console

ENV APP_ID=1026340 \
    CONFIG_DIR=/config/barotrauma \
    SERVER_DIR=/data/barotrauma \
    SETTINGS_TEMPLATE_FILE=/opt/barotrauma/serversettings.xml.tmpl \
    STEAMCMD_VALIDATE=false \
    UPDATE_ON_START=true \
    WORKSHOP_APP_ID=602960 \
    XDG_DATA_HOME=/data/state

EXPOSE 27015/udp 27016/udp

USER steam
WORKDIR /data/barotrauma

ENTRYPOINT ["/usr/local/bin/barotrauma-entrypoint"]
CMD ["./DedicatedServer"]
