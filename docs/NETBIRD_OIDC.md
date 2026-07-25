# NetBird OIDC: embedded Dex cannot reach Authentik

Incident 2026-07-23/25. Login at `netbird.krahl.io` dead-ends on Dex's error page instead of
redirecting to Authentik.

## Why this can break at all

NetBird management embeds Dex (`issuer: https://netbird.krahl.io/oauth2`, see
`netbird/config.yaml`). Authentik is an **OIDC connector inside that Dex**, not a plain
browser redirect target: Dex opens the connector **server-side** on every authorize request
and fetches `https://auth.krahl.io/application/o/netbird/.well-known/openid-configuration`.

So `netbird-server` on the VPS must be able to reach `auth.krahl.io` itself. Two independent
things broke that path.

## Cause 1: split-horizon DNS handed the VPS an unroutable LAN address

```text
failed to create connector authentik-...: failed to get provider:
Get "https://auth.krahl.io/.../openid-configuration": dial tcp 192.168.178.4:443: i/o timeout
```

The NetBird nameserver group `Pi-hole` (`100.69.0.53`, match domain `krahl.io`) was
distributed to group `All`, which includes the VPS peer itself. `systemd-resolved` then routes
every `*.krahl.io` query out `wt0`:

```text
wt0: Bus client set search domain list to: ~krahl.io., netbird.selfhosted., ~69.100.in-addr.arpa.
```

Pi-hole answers its split-horizon wildcard `address=/krahl.io/192.168.178.4`. The VPS has no
route to the home LAN (`wt0` carries only `100.69.0.0/16`, `netbird status` → `Networks: -`),
so RFC1918 leaves via `eth0` into the Hetzner uplink and is black-holed — hence `i/o timeout`,
not `connection refused`.

The VPS is both a NetBird peer and a client of the split horizon it serves. Any `*.krahl.io`
host it must call server-side hits this, not just Authentik.

**Fix:** nameserver group `Pi-hole` distribution changed from `All` to `VPN User` +
`Admin Clients` (2026-07-25). Do not use `Admins` or `Servers` — both contain `homelab-vps`.
The other server peers lose nothing: `p3-tiny` already resolves via `192.168.178.2` on its LAN
link, `fuchsbau-backbone` is Pi-hole.

## Cause 2: the NetBird RP geo-restriction rejects hairpinned requests

With DNS fixed, the VPS resolved `auth.krahl.io` publicly to its own IP and the request
entered `netbird-proxy`, which now fronts that host:

```text
status=403 source=172.30.0.1 origin=auth service=d9h2a0icm8mc73fk11pg
ERRO [auth_mechanism: country_restricted, source_ip: 172.30.0.1, response_code: 403]
```

The RP service carries `restrictions: {"allowed_countries":["DE","IT","FR"]}`. A hairpinned
request arrives from `172.30.0.1` (the `netbird` bridge gateway); a private IP has no GeoIP
country, and an allowlist denies whatever it cannot match.

This cannot be fixed with an access policy. NetBird evaluates CIDR → country → CrowdSec as a
compounding pipeline where only *denial* short-circuits. Tested 2026-07-25 by adding
`allowed_cidrs: ["172.0.0.0/8", "100.64.0.0/10"]`:

- the Docker-sourced request still got 403 `country_restricted` — matching a CIDR allowlist
  does not skip the country layer;
- **and every public client got 403 too**, because a non-empty `allowed_cidrs` rejects all
  IPs outside it. Verified from the homeserver's public egress. Reverted immediately.

## Why the old VPS-Traefik route did not have this problem

Before commit `2ef87a3` ("remove traefik ingress for authentik", 2026-07-24), `auth.krahl.io`
was an ordinary Traefik router in `traefik/config/dynamic/srv-authentik.yml`, proxying to
`https://100.69.1.1:443` over the mesh. Its geo filter is the Traefik geoblock plugin
(`traefik/config/dynamic/mi-geoblock.yml`), which has the two properties NetBird's RP lacks:

- `allowLocalRequests: true` plus an `allowedIPAddresses` bypass covering `172.0.0.0/8` and
  `100.64.0.0/10` — the geo layer is skipped for internal sources;
- `blackListMode: true` — a blocklist of 22 countries, so "no country" is allowed by default,
  the inverse of the RP's allowlist.

Restoring that router (revert `2ef87a3`, delete the RP service so it stops renewing an unused
ACME cert) is the alternative fix. Not taken: the RP setup is being kept.

## Applied fix

`extra_hosts` on `netbird-server` in `netbird/docker-compose.yml`:

```yaml
    extra_hosts:
      - "auth.krahl.io:100.69.1.1"
```

`100.69.1.1` is the homeserver's mesh IP. Home Traefik routes on the `Host` header, so TLS and
vhost matching stay correct, and the request never touches the geo-restricted RP path.

`extra_hosts` is a container-create property — `docker compose up -d --force-recreate
netbird-server` is required, a `restart` keeps the old `/etc/hosts`.

Limits: IPv4-only, scoped to this one container, and it breaks silently if the homeserver's
NetBird IP changes.

## Verification

```console
$ docker exec netbird-server grep auth.krahl.io /etc/hosts
100.69.1.1 auth.krahl.io
$ curl -o /dev/null -w '%{http_code}\n' \
    "https://netbird.krahl.io/oauth2/auth/authentik-<connector-id>?client_id=netbird-dashboard&\
redirect_uri=https%3A%2F%2Fnetbird.krahl.io%2Fnb-auth&response_type=code&scope=openid&state=x&nonce=y"
302
$ docker logs netbird-server --since 5m 2>&1 | grep -c "failed to create connector"
0
```

302 means Dex opened the connector and is redirecting to Authentik. Any 200 here is the Dex
error page, i.e. still broken.

## Timeline and ruled-out causes

First `failed to create connector` in Loki: 2026-07-23 12:33:43 UTC. Not necessarily the real
start — Loki holds no `host="vps"` data before 2026-07-21 23:51, since the Alloy agent was
only deployed then.

Ruled out by timestamp or file history:

- `netbird/config.yaml` (IdP block) unchanged since 2026-05-14.
- Pi-hole `dnsmasq_lines` unchanged since first tracked (2026-07-21).
- The 0.75.0 bump (2026-07-24 09:31) and `expose metrics to vpn` (2026-07-23 19:07) are both
  **after** the first error.
- Not a route regression — the VPS never had a `192.168.178.0/24` route.
- The RP service for `auth.krahl.io` was created 2026-07-23 14:28 UTC, also after the first
  error. It caused the second failure mode, not the first.

Closest evidence for cause 1's trigger: activity event `37 NameserverGroupUpdated` on group
`Pi-hole` at 2026-07-14 10:51:28 UTC (`events.db`). NetBird stores only `{"name":"Pi-hole"}`
in the event meta, so which field changed is not recorded. Suggestive, not proof.

## Upstream status

No supported solution as of 0.75.0. All three issues are open with no maintainer response:

| Issue | Opened | Asks for |
| --- | --- | --- |
| [netbird#5948][i5948] | 2026-04-21 | OIDC discovery shim in the RP, for exactly this embedded-Dex ↔ RP circular dependency. Lists `extra_hosts` **pointing at the local Traefik** as ineffective; ours points at the home peer's mesh IP instead, bypassing the local proxy. |
| [netbird#5861][i5861] | 2026-04-12 | NetBird Networks as an RP restriction source, to exempt internal traffic without hand-maintained CIDRs. |
| [dashboard#597][i597] | 2026-03-26 | IP/range bypass for country blocking — same class of problem, compares to Traefik's geoblock plugin. |

Official guidance for the 403 is only "remove or adjust the geo-restriction"
([RP troubleshooting][d-tshoot]).

Homeserver-side context: the split horizon itself is documented in
`/opt/homelab/ARCHITECTURE.md` ("DNS Split-Horizon"). A per-host `server=/auth.krahl.io/#`
carve-out there was rejected — it would push LAN clients through the VPS relay for Authentik
instead of straight to the homeserver.

[i5948]: https://github.com/netbirdio/netbird/issues/5948
[i5861]: https://github.com/netbirdio/netbird/issues/5861
[i597]: https://github.com/netbirdio/dashboard/issues/597
[d-tshoot]: https://docs.netbird.io/manage/reverse-proxy/troubleshooting
