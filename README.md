## Prosody version

Prosody is compiled from the [release archive](https://prosody.im/downloads/source/), on Alpine. Images built from `main` are tagged with the version (`13.0.8`) and the minor version (`13.0`). The weekly build publishes these tags again with the latest Alpine packages, so pin the digest as well if you need the exact same image.

The version is `PROSODY_VERSION` in the `Dockerfile`. Renovate updates it when a release is published: patch releases (`13.0.x`) are merged automatically once the test build passes, other versions get a pull request.

### Signature check

The build downloads the archive with its signature (`.asc`) and stops if the archive is not signed by the key whose fingerprint is `PROSODY_KEY` in the `Dockerfile`: the key of Matthew Wild, `32A9 EDDE 3609 931E B98C EAC3 1590 7E8E 7BDD 6BFE`. The key is fetched from keys.openpgp.org, or keyserver.ubuntu.com when the first one fails; the fingerprint guarantees it is the right key. It expired in September 2025 but still signs the releases, and `gpgv` does not check the expiry date.

If a release is signed by another key, the build fails with `Can't check signature: No public key`. Check the new fingerprint with the Prosody team before changing `PROSODY_KEY`.

## Config

Everything Prosody needs is in the `/data` volume:

| Path | Content |
|---|---|
| `/data/prosody.cfg.lua` | Configuration file |
| `/data/certs` | Certificates |
| `/data/storage` | Accounts, rooms and other data |
| `/data/plugins` | Community modules, optional |

Keeping everything under `/data` is what lets Prosody run as any non-root user: the user only needs to own the mounted folder. The image ships no configuration in `/data`, so you must provide `/data/prosody.cfg.lua` before the first start, otherwise Prosody stops with `Prosody was unable to find the configuration file`.

Create the folders first:

```
mkdir -p data/certs data/storage
```

`data/storage` must exist before the first start, otherwise Prosody cannot create its admin socket and `prosodyctl shell` fails until the next restart.

Then start from one of these two files:

1. **The sample of this repository (recommended)**, already set up for the container: paths under `/data`, pid file in `/tmp`, logs to the console (`docker logs`), and listening on all interfaces so Prosody can be reached from outside the container.

   ```
   curl -fsSL -o data/prosody.cfg.lua https://raw.githubusercontent.com/jee-r/docker-prosody/main/prosody.cfg.lua.sample
   ```

2. **The default configuration of Prosody**, shipped in the image as `/etc/prosody/prosody.cfg.lua`:

   ```
   docker run --rm --entrypoint cat ghcr.io/jee-r/prosody:13.0 /etc/prosody/prosody.cfg.lua > data/prosody.cfg.lua
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

## PROSODY_CONFIG

The image sets `PROSODY_CONFIG=/data/prosody.cfg.lua`. Both `prosody` and `prosodyctl` read this variable to find the configuration file, so `prosodyctl` works inside the container without `--config`. The default configuration in `/etc/prosody` is never used unless you point the variable to it.

To keep the configuration somewhere else, mount it and set the variable, for example `PROSODY_CONFIG=/config/prosody.cfg.lua`. Relative paths in the file, such as `certificates = "certs"`, are relative to the directory of the configuration file: use absolute paths when it is not `/data`.

## Running as root

The image has no `USER`: Prosody runs as the user given to the container (`user:` in compose), root by default. Prosody refuses to start as root unless the configuration contains:

```lua
run_as_root = true
```

Running as a non-root user (`user: 1000:1000` below) does not need it, but `/data` must then belong to that user.

## prosodyctl

```
docker exec prosody prosodyctl check config
docker exec prosody prosodyctl reload
docker exec -it prosody prosodyctl adduser user@example.com
docker exec -it prosody prosodyctl shell
```

The image does not declare any volume: mount `/data` yourself.

## Docker Compose

Create `./data` as explained in [Config](#config), owned by the user given in `user:`.

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
