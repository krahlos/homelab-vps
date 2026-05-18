# Architecture

## Overview

Monolithic repository for Hetzner VPS. Acts as public ingress relay and VPN management
node for the homelab. Services that require a stable public IPv4 (no CGNAT) run here.

Each service owns a directory with `docker-compose.yml`, `docker-compose.override.yml`, `systemd/`,
`config/`, and `.env`. All services run as dedicated system users (UIDs 901–919). Persistent data
in `/data/docker/volumes/`. Secrets in `/opt/secrets/<service>/`. File permissions:
dirs `750`, files `640`.

---

## Physical / Network Identity

| Property    | Value                                    |
| ----------- | ---------------------------------------- |
| Provider    | Hetzner                                  |
| Public IPv4 | `178.105.54.209`                         |
| Public IPv6 | `2a01:4f8:1c18:2c2f::1`                  |
| Netbird IP  | `100.69.0.1`                             |
| Role        | Netbird management, HAProxy mail ingress |

---

## Services

| Service        | Purpose                                                                          |
| -------------- | -------------------------------------------------------------------------------- |
| Netbird server | WireGuard mesh management; all clients connect here                              |
| HAProxy        | TCP proxy for all mail ports (25/143/465/587/993) -> homeserver over Netbird     |
| Traefik        | HTTPS reverse proxy for `mail.krahl.io` webmail -> homeserver over Netbird       |

---

## DNS Records (VPS-owned)

| Name         | Type | Value                                      |
| ------------ | ---- | ------------------------------------------ |
| `netbird`    | A    | `178.105.54.209`                           |
| `mail`       | A    | `178.105.54.209`                           |

Wildcard `*.netbird CNAME netbird.krahl.io.` covers Netbird management UI subdomains.

---

## Connectivity to Homeserver

Homeserver sits behind CGNAT (no inbound IPv4). VPS bridges the gap:

- **Mail**: HAProxy receives all public mail ports and TCP-proxies them to the
  homeserver Mailcow stack over Netbird (`100.69.1.1`). Traefik handles HTTPS
  for the `mail.krahl.io` webmail UI. HAProxy forwards real client IPs to
  Postfix via PROXY protocol v2 (`send-proxy-v2` on port 25).
- **VPN**: homeserver initiates WireGuard tunnel to VPS (`100.69.0.1`); all Netbird
  mesh traffic flows through here

---

## Netbird Topology

| Peer         | Netbird IP    | Role                |
| ------------ | ------------- | ------------------- |
| VPS          | `100.69.0.1`  | Management server   |
| Homeserver   | `100.69.1.1`  | Primary Docker host |
| Raspberry Pi | `100.69.0.53` | Pi-hole / local DNS |
