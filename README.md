## Prosody version

Prosody is compiled from the [release archive](https://prosody.im/downloads/source/), on Alpine. Images built from `main` are tagged with the version (`13.0.8`) and the minor version (`13.0`). The weekly build publishes these tags again with the latest Alpine packages, so pin the digest as well if you need the exact same image.

The version is `PROSODY_VERSION` in the `Dockerfile`. Renovate updates it when a release is published: patch releases (`13.0.x`) are merged automatically once the test build passes, other versions get a pull request.

### Signature check

The build downloads the archive with its signature (`.asc`) and stops if the archive is not signed by the key whose fingerprint is `PROSODY_KEY` in the `Dockerfile`: the key of Matthew Wild, `32A9 EDDE 3609 931E B98C EAC3 1590 7E8E 7BDD 6BFE`. The key is fetched from keys.openpgp.org, or keyserver.ubuntu.com when the first one fails; the fingerprint guarantees it is the right key. It expired in September 2025 but still signs the releases, and `gpgv` does not check the expiry date.

If a release is signed by another key, the build fails with `Can't check signature: No public key`. Check the new fingerprint with the Prosody team before changing `PROSODY_KEY`.

## Config

copy `data/prosody.cfg.lua.sample` to `data/prosody.cfg.lua` and edit it.

The pid file should be in `/tmp` or in another directory the user running Prosody can write to, for example `pidfile = "/tmp/prosody.pid"`.

we need to set interfaces to   to expose so prosody server is joinable outside of the container eg: `c2s_interfaces = { "0.0.0.0", "::" }`

## Running as root

The image has no `USER`: Prosody runs as the user given to the container (`user:` in compose), root by default. Prosody refuses to start as root unless the configuration contains:

```lua
run_as_root = true
```

Running as a non-root user (`user: 1000:1000` below) does not need it, but `/data` must then belong to that user.

## Configuration file and prosodyctl

The configuration file is `/data/prosody.cfg.lua`. The path is set by the `PROSODY_CONFIG` environment variable, which both `prosody` and `prosodyctl` read, so `prosodyctl` works inside the container without `--config`:

```
docker exec prosody prosodyctl check config
docker exec prosody prosodyctl reload
docker exec -it prosody prosodyctl adduser user@example.com
docker exec -it prosody prosodyctl shell
```

To keep the configuration somewhere else, mount it and set the variable, for example `PROSODY_CONFIG=/config/prosody.cfg.lua`. Paths in the file such as `certificates = "certs"` are relative to the directory of the configuration file, use absolute paths when it is not `/data`.

The image does not declare any volume: mount `/data` yourself (certificates, plugins, storage).

## Docker Compose

```yaml
services:
  prosody:
    image: ghcr.io/jee-r/prosody:13.0
    container_name: prosody
    user: 1000:1000
    restart: unless-stopped
    networks:
      - prosody
    ports:
      - 5222:5222
      - 5269:5269
      - 5280:5280
      - 5281:5281
    environment:
      - TZ=Europe/Paris
    volumes:
      - ./data:/data
      - /etc/localtime:/etc/localtime:ro

networks:
  prosody:
```

`13.0` follows the latest 13.0.x release. Use `13.0.8` to stay on one release, and add `@sha256:<digest>` to keep the exact same image.
