FROM ghcr.io/f0rkz/docker-steamcmd:latest
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -yq && \
    apt install -y --no-install-recommends \
        libssl-dev

ADD https://github.com/williambailey/go-envtmpl/releases/download/v0.3.0/envtmpl_0.3.0_linux_amd64.tar.gz /tmp
RUN tar zxfv /tmp/envtmpl_0.3.0_linux_amd64.tar.gz -C /tmp
RUN cp /tmp/envtmpl_0.3.0_linux_amd64/envtmpl /usr/local/bin && rm -rf /tmp/envtmpl*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /config/barotrauma

COPY serversettings.xml.tmpl /config/barotrauma/serversettings.xml.tmpl

VOLUME [ "/data" ]

CMD /entrypoint.sh
