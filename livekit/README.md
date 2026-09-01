# LiveKit

MatrixRTC media backend for Matrix calls: the LiveKit SFU plus the
[MatrixRTC Authorization Service][lk-jwt] (`lk-jwt-service`), which trades a
Matrix OpenID token for a LiveKit JWT.

Public entry is `rtc.krahl.io` via VPS Traefik
(`traefik/config/dynamic/srv-livekit.yml`), path-split into `/livekit/sfu`
(SFU WebSocket) and `/livekit/jwt` (auth). Signalling for Matrix itself is
unchanged and still goes to Synapse at home.

Matrix-side setup — Synapse config, the `rtc_foci` announcement, the Pi-hole
carve-out, glossary and end-to-end verification: [`matrix/README.md` §
Voice-over-IP][plan] in the home-server repo.

## Why it runs here and not on the home server

The home ISP is CGNAT, so the home server has no inbound IPv4, and WebRTC media
is UDP — HAProxy is TCP-only and cannot relay it. This VPS has the public IPv4
and is already the ingress, so media terminates here.

## Gotchas

- **`network_mode: host` for both containers.** LiveKit must see the real
  public IP or it advertises `172.x` bridge addresses as ICE candidates and no
  call connects. `lk-jwt-service` follows so Traefik reaches both at the bridge
  gateway `172.30.0.1`.
- **`rtc.node_ip`, not top-level `node_ip`.** At top level LiveKit silently
  ignores it and ICE advertises the wrong address.
- **`turn.enabled: false` is load-bearing.** LiveKit ships an embedded TURN on
  `3478/udp`, the port NetBird already binds here. Enabling it breaks the mesh.
- **`lk-jwt-service` binds `:8090`, not the upstream default `:8080`.**
  cadvisor already owns `8080` on this host and both are host-network.
- **`LIVEKIT_URL` must be the public `wss://` origin.** It is echoed back to
  clients in the JWT; a loopback value makes every client dial itself.
- **No CrowdSec/geoblock/rate-limiter chain on these routers.** A call opens
  many rapid requests per participant and the rate limiter drops them mid-call.
- **`lk-jwt-service` ghcr tags carry no `v` prefix** (`0.5.0`), unlike the git
  release tag. Copying the release tag verbatim gives `not found` at pull time.
- **Pi-hole needs `server=/rtc.krahl.io/#`.** The `krahl.io` wildcard otherwise
  points LAN clients at the home server and every call from home breaks. It
  answers with the home Traefik `reject-catchall` 418, while calls from cellular
  keep working — so it reads as a client fault, not DNS.
- **UDP socket buffers.** The kernel default is too small for an SFU and the
  kernel drops media datagrams under load — choppy audio, frozen video, no
  connection error. `homelab-vps/etc/sysctl.d/99-livekit.conf` raises
  `rmem_max`/`wmem_max`; LiveKit must be restarted after applying it.

## Credentials

`.env` and `livekit.yaml` are symlinks into `/opt/secrets/livekit/`
(`livekit.conf` and `livekit.yaml`) — edit the targets, never the links.

`LIVEKIT_KEY` / `LIVEKIT_SECRET` in `.env` must match the `keys:` block in
`livekit.yaml`, and `webhook.api_key` must be the same key. Regenerate with:

```shell
LK_KEY="API$(openssl rand -hex 8)"
LK_SECRET="$(openssl rand -base64 48 | tr -d "\n=+/" | cut -c1-48)"
```

## Checks

```shell
docker compose -p livekit config
curl -s http://127.0.0.1:8090/healthz
curl -s https://rtc.krahl.io/livekit/jwt/healthz
```

[lk-jwt]: https://github.com/element-hq/lk-jwt-service
[plan]: https://github.com/krahlos/homelab/blob/main/matrix/README.md#voice-over-ip-voip
