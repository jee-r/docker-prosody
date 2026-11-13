## Config

copy `data/prosody.cfg.lua.sample` to `data/prosody.cfg.lua` and edit it.

as we run prosody as a non-root user pid should be in `/tmp` or in a user writable directory.

we need to set interfaces to   to expose so prosody server is joinable outside of the container eg: `c2s_interfaces = { "0.0.0.0", "::" }`

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

```
version: '3.9'

services:
  prosody:
    image: ghcr.io/jee-r/prosody:main
    container_name: prosody
    build:
      context: .
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