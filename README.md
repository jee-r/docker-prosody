## Config

copy `data/prosody.cfg.lua.sample` to `data/prosody.cfg.lua` and edit it.

as we run prosody as a non-root user pid should be in `/tmp` or in a user writable directory.

we need to set interfaces to   to expose so prosody server is joinable outside of the container eg: `c2s_interfaces = { "0.0.0.0", "::" }`

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