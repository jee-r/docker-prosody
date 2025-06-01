FROM alpine:3.22

LABEL name="docker-prosody" \
      maintainer="Jee jee@jeer.fr" \
      description="Lua based Jabber/XMPP server" \
      url="https://prosody.im/" \
      org.label-schema.vcs-url="https://github.com/jee-r/docker-prosody" \
      org.opencontainers.image.source="https://github.com/jee-r/docker-prosody"

RUN apk update && \
	apk upgrade --no-cache && \
	apk add --upgrade --no-cache \
		prosody \
		bash && \
	rm -rf /tmp/* /var/cache/apk/* 

EXPOSE 	5222 \
		5269 \
		5280 \
		5281

WORKDIR /data
VOLUME /config

STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=30s --timeout=60s --start-period=30s \
	CMD /usr/bin/prosodyctl --config /data/prosody.cfg.lua status

ENTRYPOINT ["/usr/bin/prosody", "--no-daemonize", "--config", "/data/prosody.cfg.lua"]

