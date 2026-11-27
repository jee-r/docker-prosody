ARG ALPINE_VERSION=3.24

ARG PROSODY_VERSION=13.0.8

# Fingerprint of the key that signs the Prosody releases (Matthew Wild),
# see "Prosody version" in the README
ARG PROSODY_KEY=32A9EDDE3609931EB98CEAC315907E8E7BDD6BFE

FROM alpine:${ALPINE_VERSION} AS build

ARG PROSODY_VERSION
ARG PROSODY_KEY

RUN apk add --no-cache \
		build-base \
		gnupg \
		gnupg-dirmngr \
		gpgv \
		icu-dev \
		linux-headers \
		lua5.4-dev \
		openssl-dev

WORKDIR /src

# The key is fetched by its fingerprint, and only that key is exported to
# the keyring gpgv uses. gpgv ignores the expiry date of the key.
# Same configure options as the Alpine package.
RUN cd /tmp && \
	export GNUPGHOME="$(mktemp -d)" && \
	{ gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "${PROSODY_KEY}" || \
	  gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "${PROSODY_KEY}"; } && \
	gpg --batch --export "${PROSODY_KEY}" > prosody-release.gpg && \
	wget -q "https://prosody.im/downloads/source/prosody-${PROSODY_VERSION}.tar.gz" \
		"https://prosody.im/downloads/source/prosody-${PROSODY_VERSION}.tar.gz.asc" && \
	gpgv --keyring ./prosody-release.gpg \
		"prosody-${PROSODY_VERSION}.tar.gz.asc" "prosody-${PROSODY_VERSION}.tar.gz" && \
	cd /src && \
	tar -xzf "/tmp/prosody-${PROSODY_VERSION}.tar.gz" --strip-components=1 && \
	./configure \
		--prefix=/usr \
		--sysconfdir=/etc/prosody \
		--ostype=linux \
		--with-lua-lib=/usr/lib \
		--with-lua-include=/usr/include \
		--lua-version=5.4 \
		--no-example-certs \
		--runwith=lua5.4 && \
	rm -f certs/Makefile certs/makefile && \
	make -j"$(nproc)" && \
	make DESTDIR=/out install

FROM alpine:${ALPINE_VERSION}

ARG PROSODY_VERSION

LABEL name="docker-prosody" \
      maintainer="Jee jee@jeer.fr" \
      description="Lua based Jabber/XMPP server" \
      url="https://prosody.im/" \
      org.label-schema.vcs-url="https://github.com/jee-r/docker-prosody" \
      org.opencontainers.image.source="https://github.com/jee-r/docker-prosody" \
      org.opencontainers.image.version="${PROSODY_VERSION}"

# The prosody user keeps the uid and gid of the Alpine package
RUN apk upgrade --no-cache && \
	apk add --no-cache \
		bash \
		ca-certificates \
		icu-data-full \
		icu-libs \
		libcrypto3 \
		libssl3 \
		libstdc++ \
		lua5.4 \
		lua5.4-expat \
		lua5.4-filesystem \
		lua5.4-sec \
		lua5.4-socket \
		lua5.4-unbound \
		tzdata && \
	addgroup -S -g 101 prosody && \
	adduser -S -D -H -u 100 -G prosody -g prosody \
		-h /var/lib/prosody -s /sbin/nologin prosody

COPY --from=build /out/ /

RUN install -d -o prosody -g prosody /var/log/prosody /var/run/prosody && \
	install -d -m 750 -o prosody -g prosody /var/lib/prosody

EXPOSE 	5222 \
		5269 \
		5280 \
		5281

WORKDIR /data

# Read by prosody and by prosodyctl, so none of them needs --config.
# Override it to keep the configuration elsewhere.
ENV PROSODY_CONFIG=/data/prosody.cfg.lua

HEALTHCHECK --interval=30s --timeout=60s --start-period=30s \
	CMD /usr/bin/prosodyctl status

ENTRYPOINT ["/usr/bin/prosody", "--no-daemonize"]
