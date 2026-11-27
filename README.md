# Prosody docker image

[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/j33r/prosody?style=flat-square)](https://hub.docker.com/r/j33r/prosody)
![GitHub Workflow Status (branch)](https://img.shields.io/github/actions/workflow/status/jee-r/docker-prosody/deploy.yaml?branch=main&style=flat-square)
[![Docker Pulls](https://img.shields.io/docker/pulls/j33r/prosody?style=flat-square)](https://hub.docker.com/r/j33r/prosody)
[![DockerHub](https://img.shields.io/badge/Dockerhub-j33r/prosody-%232496ED?logo=docker&style=flat-square)](https://hub.docker.com/r/j33r/prosody)
[![ghcr.io](https://img.shields.io/badge/ghcr%2Eio-jee%2D-r/prosody-%232496ED?logo=github&style=flat-square)](https://ghcr.io/jee-r/prosody)

A docker image for [Prosody](https://prosody.im), compiled from the signed release archive on [Alpine Linux](https://alpinelinux.org).

**Multi-architecture support:** `linux/amd64`, `linux/arm64`, `linux/arm/v7`

**Available tags:**
- `latest`, `main` - Latest build of the `main` branch
- `<major>.<minor>`, `<major>.<minor>.<patch>` - Prosody versions (e.g., `13.0`, `13.0.8`)
- `<commit-sha>` - Specific commit

The weekly build publishes these tags again with the latest Alpine packages: pin the digest as well (`13.0.8@sha256:…`) if you need the exact same image.

## What is Prosody

From [prosody.im](https://prosody.im/):

> Prosody is a modern XMPP communication server. It aims to be easy to set up and configure, and efficient with system resources. Additionally, for developers it aims to be easy to extend and give a flexible system on which to rapidly develop added functionality, or prototype new protocols.
>
> Prosody is open-source software under the permissive MIT/X11 license.

## How to use this image

Prepare the `data` folder first, see [Volumes](#volumes) and [Configuration](#configuration): Prosody does not start without a configuration file.

We recommend [Podman](https://podman.io), ideally in [rootless mode](https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode): the containers then run without any root process on the host. The commands below work the same with Docker.

### With Podman / Docker

```bash
podman run \
    --detach \
    --name prosody \
    --user $(id -u):$(id -g) \
    --volume ./data:/data \
    --env TZ=Europe/Paris \
    --publish 5222:5222 \
    --publish 5269:5269 \
    --publish 5280:5280 \
    --publish 5281:5281 \
    ghcr.io/jee-r/prosody:13.0
```

**Notes:**
- `--user $(id -u):$(id -g)` runs Prosody as your user, which must own `./data`. Replace it with other ids if needed.
- Replace `podman` with `docker` if you use Docker.
- 5222 is for clients, 5269 for other servers (s2s), 5280 and 5281 for HTTP and HTTPS (BOSH, websocket, file upload). Publish only the ports you use.

### With Compose

```yaml
services:
  prosody:
    image: ghcr.io/jee-r/prosody:13.0
    container_name: prosody
    restart: unless-stopped
    user: "1000:1000"
    volumes:
      - ./data:/data
    environment:
      - TZ=Europe/Paris
    ports:
      - 5222:5222
      - 5269:5269
      - 5280:5280
      - 5281:5281
```

`13.0` follows the latest 13.0.x release. Use `13.0.8` to stay on one release.

## Volumes

Everything Prosody needs is in `/data`:

| Path | Content |
|---|---|
| `/data/prosody.cfg.lua` | Configuration file |
| `/data/certs` | Certificates |
| `/data/storage` | Accounts, rooms and other data |
| `/data/plugins` | Community modules, optional |

The user running the container must own the folder. The image does not declare any volume, mount `/data` yourself.

Create the folders before the first start:

```bash
mkdir -p data/certs data/storage
```

Without `data/storage`, Prosody cannot create its admin socket at the first start, and `prosodyctl shell` fails until the next restart.

## Configuration

The image ships no configuration in `/data`: you must provide `/data/prosody.cfg.lua`, otherwise Prosody stops with `Prosody was unable to find the configuration file`. Start from one of these two files:

1. **The [sample](prosody.cfg.lua.sample) of this repository (recommended)**, already set up for the container: paths under `/data`, pid file in `/tmp`, logs to stdout, and listening on all interfaces so Prosody can be reached from outside the container.

   ```bash
   curl -fsSL -o data/prosody.cfg.lua https://raw.githubusercontent.com/jee-r/docker-prosody/main/prosody.cfg.lua.sample
   ```

2. **The default configuration of Prosody**, shipped in the image as `/etc/prosody/prosody.cfg.lua`:

   ```bash
   podman run --rm --entrypoint cat ghcr.io/jee-r/prosody:13.0 /etc/prosody/prosody.cfg.lua > data/prosody.cfg.lua
   ```

   It is not set up for the container: it keeps the data in `/var/lib/prosody`, inside the container and writable only by root or the `prosody` user of the image, and writes its logs to files. Add these options to the global section, before the first `VirtualHost`, and remove its `log = { … }` block:

   ```lua
   pidfile = "/tmp/prosody.pid"
   data_path = "/data/storage"
   plugin_paths = { "/data/plugins" }
   log = { info = "*console" }
   c2s_interfaces = { "0.0.0.0", "::" }
   http_interfaces = { "*", "::" }
   ```

### Running as root

Prosody refuses to start as root unless the configuration contains:

```lua
run_as_root = true
```

The image has no `USER`, so this happens when you do not set `--user` (or `user:` in Compose).

## Environment variables

- `TZ`: timezone of the container (default: UTC). See the full list on [Wikipedia](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). Mounting `/etc/localtime:/etc/localtime:ro` from the host works too.
- `PROSODY_CONFIG`: path of the configuration file (default: `/data/prosody.cfg.lua`). Both `prosody` and `prosodyctl` read it, so `prosodyctl` works without `--config`. The default configuration in `/etc/prosody` is never used unless you point the variable to it. Relative paths in the file, such as `certificates = "certs"`, are relative to the directory of the configuration file: use absolute paths when it is not in `/data`.
## Logs

The sample configuration logs from the `info` level to stdout:

```bash
podman logs prosody
# or
docker logs prosody
```

Change `info` to `debug` in the `log` block of the configuration for verbose logging.

## prosodyctl

```bash
podman exec prosody prosodyctl check config
podman exec prosody prosodyctl reload
podman exec -it prosody prosodyctl adduser user@example.com
podman exec -it prosody prosodyctl shell
```

## Building

Prosody is compiled from the [release archive](https://prosody.im/downloads/source/), with the configure options of the Alpine package. The version is `PROSODY_VERSION` in the `Dockerfile`. Renovate updates it when a release is published: patch releases (`13.0.x`) are merged automatically once the test build passes, other versions get a pull request.

### Signature check

The build downloads the archive with its signature (`.asc`) and stops if the archive is not signed by the key whose fingerprint is `PROSODY_KEY` in the `Dockerfile`: the key of Matthew Wild, `32A9 EDDE 3609 931E B98C EAC3 1590 7E8E 7BDD 6BFE`. The key is fetched from keys.openpgp.org, or keyserver.ubuntu.com when the first one fails; the fingerprint guarantees it is the right key. It expired in September 2025 but still signs the releases, and `gpgv` does not check the expiry date.

If a release is signed by another key, the build fails with `Can't check signature: No public key`. Check the new fingerprint with the Prosody team before changing `PROSODY_KEY`.
