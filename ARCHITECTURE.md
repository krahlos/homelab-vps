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

| Property    | Value                          |
| ----------- | ------------------------------ |
| Provider    | Hetzner                        |
| Public IPv4 | `178.105.54.209`               |
| Public IPv6 | `2a01:4f8:1c18:2c2f::1`        |
| Netbird IP  | `100.69.0.1`                   |
| Role        | Netbird management, SMTP relay |

---

## Services

| Service        | Purpose                                                     |
| -------------- | ----------------------------------------------------------- |
| Netbird server | WireGuard mesh management; all clients connect here         |
| SMTP relay     | Receives inbound mail; relays outbound for homeserver       |

---

## DNS Records (VPS-owned)

| Name         | Type | Value                    |
| ------------ | ---- | ------------------------ |
| `netbird`    | A    | `178.105.54.209`         |
| `mail-relay` | A    | `178.105.54.209`         |
| `mail-relay` | AAAA | `2a01:4f8:1c18:2c2f::1`  |

Wildcard `*.netbird CNAME netbird.krahl.io.` covers Netbird management UI subdomains.

---

## Connectivity to Homeserver

Homeserver sits behind CGNAT (no inbound IPv4). VPS bridges the gap:

- **Mail**: inbound SMTP lands on VPS relay, forwarded to homeserver over Netbird
  (`100.69.1.1`)
  - Only a _temporary_ workaround until haproxy bridges mail traffic via WireGuard
    to the homeserver
- **VPN**: homeserver initiates WireGuard tunnel to VPS (`100.69.0.1`); all Netbird
  mesh traffic flows through here

---

## Netbird Topology

| Peer         | Netbird IP    | Role                |
| ------------ | ------------- | ------------------- |
| VPS          | `100.69.0.1`  | Management server   |
| Homeserver   | `100.69.1.1`  | Primary Docker host |
| Raspberry Pi | `100.69.0.53` | Pi-hole / local DNS |
