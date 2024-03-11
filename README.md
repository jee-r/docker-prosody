## Config

copy `data/prosody.cfg.lua.sample` to `data/prosody.cfg.lua` and edit it.

as we run prosody as a non-root user pid should be in `/tmp` or in a user writable directory.

we need to set interfaces to   to expose so prosody server is joinable outside of the container eg: `c2s_interfaces = { "0.0.0.0", "::" }`
