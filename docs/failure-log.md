# Failure log

Every real failure while building and running the radar. Only things that actually happened.

| Date | What broke | Why | Fix | Prevented since by |
|---|---|---|---|---|
| 2026-10-29 | n8n could not connect to Postgres: "Connection refused" with host `localhost` | On Windows, n8n can resolve `localhost` to the IPv6 address `::1`, while Postgres is published only on the IPv4 address `127.0.0.1` (localhost-only by design) | Host set to `127.0.0.1` | README option B tells users to use `127.0.0.1` if `localhost` fails |
