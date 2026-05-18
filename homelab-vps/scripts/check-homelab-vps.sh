#!/usr/bin/env bash

_in_array() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

_grep_services() {
    # get all *.service files in homelab
    local unfiltered_services=()
    while IFS= read -r line; do
        unfiltered_services+=("$line")
    done < <(find "$homelab_root" -name "*.service" -exec basename {} .service \;)

    # get all *.timer files in homelab
    local timers=()
    while IFS= read -r line; do
        timers+=("$line")
    done < <(find "$homelab_root" -name "*.timer" -exec basename {} .timer \;)

    # get all *.path files in homelab
    local paths=()
    while IFS= read -r line; do
        paths+=("$line")
    done < <(find "$homelab_root" -name "*.path" -exec basename {} .path \;)

    # remove timers and path units from services
    local services=()
    for service in "${unfiltered_services[@]}"; do
        if ! _in_array "$service" "${timers[@]}" && ! _in_array "$service" "${paths[@]}"; then
            services+=("$service")
        fi
    done

    # sort lists alphabetically and fill shared variables
    while IFS= read -r line; do
        homelab_services+=("$line")
    done < <(printf "%s\n" "${services[@]}" | sort)

    while IFS= read -r line; do
        homelab_jobs+=("$line")
    done < <(printf "%s\n" "${timers[@]}" | sort)

    while IFS= read -r line; do
        homelab_paths+=("$line")
    done < <(printf "%s\n" "${paths[@]}" | sort)
}

_print_separator() {
    local label="$1"
    local width=43
    local prefix="-- ${label} "
    local pad=$((width - ${#prefix}))
    (( pad < 3 )) && pad=3
    printf -- "%s" "$prefix"
    printf -- '-%.0s' $(seq 1 "$pad")
    printf "\n"
}

_check_services() {
    local services=("$@")

    local svc_status printed_status color display

    for service in "${services[@]}"; do
        display="$service"

        if ! systemctl cat "$service" &>/dev/null \
            && ! systemctl cat "${service}.service" &>/dev/null \
            && ! systemctl cat "${service}.path" &>/dev/null; then
            printed_status="n/a"
            color="\e[90m"    # yellow
        else
            if [[ "$service" == *.* ]]; then
                svc_status=$(systemctl is-active "$service" 2>/dev/null)
            elif systemctl cat "${service}.path" &>/dev/null 2>&1; then
                svc_status=$(systemctl is-active "${service}.path" 2>/dev/null)
            else
                svc_status=$(systemctl is-active "$service" 2>/dev/null)
            fi
            case "$svc_status" in
                active)
                    printed_status="active"
                    color="\e[32m" ;;  # green
                inactive)
                    printed_status="inactive"
                    color="\e[33m" ;;  # yellow
                failed)
                    printed_status="failed"
                    color="\e[31m" ;;  # red
                linked)
                    printed_status="linked"
                    color="\e[90m" ;; # grey
                activating|deactivating)
                    printed_status="$svc_status"
                    color="\e[36m" ;;  # cyan
                *)
                    printed_status="n/a"
                    color="\e[33m" ;;  # yellow fallback
            esac
        fi

        printf "[%b %-12s \e[0m] %s\n" \
               "$color" "$printed_status" "$display"
    done
}

stop_vps() {
    echo "-- stopping homelab-vps services ----------"
    # reverse tier order so apps stop before infra dependencies
    for target in homelab-vps-apps homelab-vps-monitoring homelab-vps-infra; do
        printf "stopping %s.target...\n" "$target"
        systemctl stop "$target.target"
    done
    echo "-- done -----------------------------------"
}

check_vps() {
    local homelab_root="/opt/homelab-vps"

    local system_services=(
        "crowdsec-firewall-bouncer"
        "docker"
        "nftables"
        "ssh"
    )

    _print_separator "system"
    _check_services "${system_services[@]}"

    local all_timers=()  # accumulates timers from all tiers for the final section
    local target
    for target in homelab-vps-infra homelab-vps-monitoring homelab-vps-apps; do
        local tier_name="${target#homelab-vps-}"  # strip "homelab-vps-" prefix for display
        _print_separator "$tier_name"

        # grep all units that declare PartOf=<target>.target, split into services and timers
        local raw_units=() tier_timers=()
        while IFS= read -r base; do
            if [[ "$base" == *.timer ]]; then
                # basename without suffix, used for filtering below
                tier_timers+=("${base%.timer}")
                # keep full name for _check_services
                all_timers+=("$base")
            else
                # strip .service/.path suffix
                raw_units+=("${base%.*}")
            fi
        done < <(grep -l "PartOf=$target.target" -r "$homelab_root" --include="*.service" --include="*.timer" --include="*.path" | xargs -r -n1 basename)

        # exclude services that have a matching timer — those appear in the timers section
        local units=()
        if [[ ${#raw_units[@]} -gt 0 ]]; then
            while IFS= read -r u; do
                if ! _in_array "$u" "${tier_timers[@]}"; then
                    units+=("$u")
                fi
            done < <(printf "%s\n" "${raw_units[@]}")
        fi

        if [[ ${#units[@]} -gt 0 ]]; then
            local sorted_units=()
            while IFS= read -r line; do
                sorted_units+=("$line")
            done < <(printf "%s\n" "${units[@]}" | sort -u)
            _check_services "${sorted_units[@]}"
        fi
    done

    # render all timers collected across tiers in one dedicated section at the end
    if [[ ${#all_timers[@]} -gt 0 ]]; then
        _print_separator "timers"
        local sorted_timers=()
        while IFS= read -r line; do
            sorted_timers+=("$line")
        done < <(printf "%s\n" "${all_timers[@]}" | sort -u)
        local timer_units=()
        for t in "${sorted_timers[@]}"; do
            timer_units+=("${t%.timer}")
        done
        _check_services "${timer_units[@]}"
    fi
}
