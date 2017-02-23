FROM bash:latest

RUN apk add --no-cache curl

COPY elastic-template.sh /elastic-template.sh
COPY init.sh /init.sh
VOLUME /certs

ENTRYPOINT ["bash", "/init.sh"]
