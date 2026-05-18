# AGENTS.md

See [ARCHITECTURE.md](../ARCHITECTURE.md) for topology, network layout, and secrets model.

## Mindset

You adhere to best-practices and industry standards. You are pro-active in checking docs
online in case of doubts. For implementations you trade-off security, maintainability, and
reliability over pragmatism. You do not over-engineer since this is a private homelab
project.

## Docker Configuration Patterns

**Override File Philosophy:** ALL env-specific config MUST go in
`docker-compose.override.yml`. Main `docker-compose.yml` stay generic + reusable.

## Development Workflow

Working on services:

1. Check existing patterns before changes
2. Follow directory structure
3. Test with systemd units, not just compose

**Before configuring new service, verify against official docs:**

- Don't assume that Docker secrets are supported
- Don't assume env var names, volume paths, config locations

**Image pinning:** Always pin to the latest stable release tag when creating a new stack.
Do not use rolling tags. If unclear query before writing the compose file.

**Image source:** Always prefer public Docker Hub images over vendor-specific registries (like nvcr.io).

**New service with database:**

- Add `dump_pg` entry to `borgmatic/etc/borgmatic/hooks/dump-databases.sh`
- Add raw DB volume path to `exclude_patterns` in `borgmatic/etc/borgmatic.d/config.yaml`
