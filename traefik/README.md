# Traefik

## Netbird

Default netbird configuration for Traefik was

```yaml
log:
  level: INFO

accessLog: {}

providers:
  docker:
    exposedByDefault: false
    network: netbird
  file:
    filename: /etc/traefik/dynamic.yaml

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    allowACMEByPass: true
    transport:
      respondingTimeouts:
        readTimeout: 0
        writeTimeout: 0
        idleTimeout: 0

certificatesResolvers:
  letsencrypt:
    acme:
      email: marco-krahl@web.de
      storage: /letsencrypt/acme.json
      tlsChallenge: {}

serversTransport:
  forwardingTimeouts:
    responseHeaderTimeout: 0s
    idleConnTimeout: 0s
```
