# NetBird

## Access Control

Policies are least-privilege per client group. Family members get exactly two flows: HTTPS to
the homeserver and DNS to Pi-hole. Everything else on the LAN and on the server peers is out
of reach for them.

| Policy | Source | Destination | Proto | Ports |
| --- | --- | --- | --- | --- |
| Default | `Admins` | `All` | all | — |
| Family Web | `Familie` | resource `Homeserver` (192.168.178.4/32) | TCP | 443 |
| Family DNS | `Familie` | `Pi-hole` (`fuchsbau-backbone`) | UDP | 53 |
| Marco Clients LAN | `Marco's clients` | resource `FritzBox Network` (192.168.178.0/24) | all | — |
| Marco Clients Servers | `Marco's clients` | `Servers` | all | — |

`Familie` and `Marco's clients` come from Authentik, hence the German name on the first.
Superseded and disabled: `Family FritzLAN Access`, `Family Server Access` (both `Familie` →
all protocols).

### Why a host resource, not a peer group

Pi-hole runs split-horizon and answers `*.krahl.io` with the LAN address `192.168.178.4`, so
client sessions reach the homeserver over the routed subnet, not over its NetBird IP
`100.69.1.1`. A peer group holding `p3-tiny` would govern the NetBird IP only and leave the
real traffic ungoverned while looking correct in the UI. The destination must therefore be a
network resource. `Homeserver` is a `/32` host resource so family peers cannot reach the
FritzBox, the Pi, or any other LAN device.

The two `Marco Clients` policies exist because `x1-carbon` and `Quindici` are members of
`Familie` but not of `Admins` — they previously drew their LAN and server access from the
Family policies.

### DNS is load-bearing

The Pi-hole nameserver (`100.69.0.53:53/udp`, domain `krahl.io`) is what makes every service
name resolve for VPN clients. Restricting a family policy to TCP breaks name resolution and
looks like a total outage. DNS over TCP 53 (truncated answers) is not permitted.

### Out of scope of these policies

- **Mail.** `mail.krahl.io` resolves to the public VPS address even from Pi-hole. Clients go
  VPS HAProxy (`25/465/587/143/993`) → `100.69.1.1`, a hop covered by `Default` since
  `homelab-vps` is in `Admins`. `autodiscover`/`autoconfig` do resolve to the LAN address and
  are HTTPS, so `Family Web` covers client setup.
- **Public traffic.** No exit node and no default route exist, so Element Call/LiveKit and
  anything else public bypasses NetBird ACLs entirely.
