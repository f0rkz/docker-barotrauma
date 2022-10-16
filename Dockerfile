FROM ghcr.io/f0rkz/docker-steamcmd:latest
USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -yq && \
    apt install -y --no-install-recommends \
        libssl-dev

ADD https://github.com/williambailey/go-envtmpl/releases/download/v0.3.0/envtmpl_0.3.0_linux_amd64.tar.gz /tmp
RUN tar zxfv /tmp/envtmpl_0.3.0_linux_amd64.tar.gz -C /tmp
RUN cp /tmp/envtmpl_0.3.0_linux_amd64/envtmpl /usr/local/bin && rm -rf /tmp/envtmpl*

COPY entrypoint.sh /home/steam/entrypoint.sh
RUN chmod +x /home/steam/entrypoint.sh
RUN chown steam:steam /home/steam/entrypoint.sh

RUN mkdir -p /home/steam/.local/share/Daedalic\ Entertainment\ GmbH/Barotrauma/
RUN chown -R steam:steam /home/steam/.local

USER steam

COPY serversettings.xml.tmpl /home/steam/serversettings.xml.tmpl

VOLUME [ "/data" ]

CMD /home/steam/entrypoint.sh
