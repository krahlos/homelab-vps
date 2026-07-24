# Homelab VPS

## Setup

### Netbird

Create the `netbird` network:

```bash
sudo docker network create \
  --driver bridge \
  --ipv6 \
  --subnet 172.30.0.0/24 \
  --gateway 172.30.0.1 \
  --subnet fd00:30::/64 \
  --gateway fd00:30::1 \
  netbird
```

Verify it with

```bash
sudo docker network inspect netbird
```

### Honeypot

To enable Honeypot, create the necessary directories and set the correct permissions:

```bash
mkdir -p honeypot/data/cowrie-{22,2222}/{log/cowrie,lib/cowrie,run}
chown -R 65534:65534 honeypot/data/
```

### Traefik

To use the Traefik reverse proxy as a traffic ingress towards the homeserver add
a service file with a router to `traefik/config/dynamic`, e.g. like this:

```yaml
---

# krahl.io — VPS ingress for the website.

http:
  routers:
    krahl-io:
      entryPoints:
        - websecure
      rule: Host(`krahl.io`)
      service: krahl-io-backend@file
      tls:
        certResolver: letsencrypt-dns
      middlewares:
        - websecure-protect@file

  services:
    krahl-io-backend:
      loadBalancer:
        serversTransport: home-server-transport
        servers:
          - url: "https://100.69.1.1:443"
```
