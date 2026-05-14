# Custom bashrc for homelab-vps

# Homelab VPS Paths
export HOMELAB_VPS_ROOT=/opt/homelab-vps
export HOMELAB_VPS_SCRIPTS="$HOMELAB_VPS_ROOT/homelab-vps/scripts"

# Source scripts
source $HOMELAB_VPS_SCRIPTS/check-homelab-vps.sh

# Update PATH
export PATH="$HOMELAB_VPS_SCRIPTS${PATH+:$PATH}"

# CrowdSec CLI alias
cscli() {
    # Return error if crowdsec container is not running or does not exist
    if ! docker ps --format '{{.Names}}' | grep -q '^crowdsec$'; then
        echo "Error: crowdsec container is not running or does not exist." >&2
        return 1
    fi

    # Execute cscli command inside the crowdsec container
    docker exec crowdsec cscli "$@"
}

pangctl() {
    # Return error if pangolin container is not running or does not exist
    if ! docker ps --format '{{.Names}}' | grep -q '^pangolin$'; then
        echo "Error: pangolin container is not running or does not exist." >&2
        return 1
    fi

    # Execute pangctl command inside the pangolin container
    docker exec pangolin pangctl "$@"
}

traefik() {
    # Return error if traefik container is not running or does not exist
    if ! docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
        echo "Error: traefik container is not running or does not exist." >&2
        return 1
    fi

    # Execute traefik command inside the traefik container
    docker exec traefik traefik "$@"
}
