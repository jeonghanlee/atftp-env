#!/bin/bash -p

set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unset BASH_ENV ENV
umask 077

readonly COMMAND_TIMEOUT=300 READY_TIMEOUT=30 IDLE_TIMEOUT=15
declare WORKSPACE='' NETWORK='' PREFIX=''
declare -a CONTAINERS=()
declare -a IMAGES=(atftp-peer:8.10 atftp-peer:10.2)
declare -a VERSIONS=(8.10 10.2)

function run {
    printf 'Command:' | tee -a "$WORKSPACE/commands.log"
    printf ' %q' "$@" | tee -a "$WORKSPACE/commands.log"
    printf '\n' | tee -a "$WORKSPACE/commands.log"
    timeout "$COMMAND_TIMEOUT" "$@" 2>&1 | tee -a "$WORKSPACE/commands.log"
}

function cleanup {
    local status=$? container
    trap - EXIT
    for container in "${CONTAINERS[@]}"; do
        docker logs "$container" > "$WORKSPACE/$container.log" 2>&1 || true
        docker rm --force "$container" >> "$WORKSPACE/cleanup.log" 2>&1 || status=1
    done
    if [[ -n $NETWORK ]]; then
        docker network rm "$NETWORK" >> "$WORKSPACE/cleanup.log" 2>&1 || status=1
    fi
    printf 'Evidence directory: %s\n' "$WORKSPACE"
    if (( status == 0 )); then
        printf '%s\n' 'PASS: two-container TFTP network lifecycle'
    else
        printf '[FAIL] network verification exited %s\n' "$status" >&2
    fi
    exit "$status"
}

function ready {
    local name=$1 deadline=$((SECONDS + READY_TIMEOUT)) state
    while :; do
        state=$(docker exec "$name" systemctl is-system-running 2>/dev/null) || true
        [[ $state == running || $state == degraded ]] && break
        if (( SECONDS >= deadline )); then
            printf '[FAIL] systemd readiness timeout: %s\n' "$name" >&2
            return 1
        fi
        sleep 0.2
    done
}

function download {
    local client=$1 server=$2
    run docker exec "$client" /src/tests/client.bash --host "$server" \
        --remote validation.txt --expected /src/tests/fixtures/download.txt
}

function main {
    local root index name container server client deadline state
    if (( $# != 0 )); then
        if [[ $# == 1 && $1 == --help ]]; then
            printf '%s\n' 'Usage: bash tests/network.bash'
            return
        fi
        printf '%s\n' 'Usage: bash tests/network.bash' >&2
        return 2
    fi
    root=$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
    cd -- "$root"
    docker info >/dev/null
    WORKSPACE=$(mktemp -d /tmp/atftp-network.XXXXXX)
    PREFIX=${WORKSPACE##*/}
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    for index in "${!VERSIONS[@]}"; do
        run docker build --file .github/ci/Dockerfile --build-arg "ROCKY_VERSION=${VERSIONS[$index]}" \
            --tag "${IMAGES[$index]}" .
    done
    NETWORK=$(docker network create "$PREFIX")
    for index in "${!VERSIONS[@]}"; do
        name=$PREFIX-${VERSIONS[$index]}
        container=$(docker run --detach --privileged --cgroupns=private \
            --tmpfs /run --tmpfs /run/lock --network "$NETWORK" --name "$name" "${IMAGES[$index]}")
        CONTAINERS+=("$container")
        ready "$name"
        run docker exec "$name" /bin/bash -p -c '
            set -euo pipefail
            cd /src
            printf "TFTPD_TIMEOUT=2\n" > configure/CONFIG_SITE.local
            make conf_install
            install -m 644 tests/fixtures/download.txt /srv/tftp/validation.txt
            install -m 666 tests/fixtures/download.txt /srv/tftp/overwrite.txt
            make service.check
            make sd_start
            systemctl is-active atftpd.socket
        '
    done
    for index in "${!VERSIONS[@]}"; do
        server=$PREFIX-${VERSIONS[$index]}
        client=$PREFIX-${VERSIONS[$((1-index))]}
        download "$client" "$server"
        run docker exec "$client" /bin/bash -p -c '
            set -euo pipefail
            server=$1
            for remote in upload.txt overwrite.txt; do
                status=0
                output=$(timeout 10 /opt/atftp/bin/atftp --tftp-timeout 2 --put \
                    --remote-file "$remote" --local-file /src/tests/client.bash "$server" 69 2>&1) || status=$?
                test "$status" -ne 0
                [[ $output == *"error received from server"* ]]
                printf "PASS: rejected peer PUT %s\n" "$remote"
            done
        ' peer "$server"
        run docker exec "$server" /bin/bash -p -c '
            set -euo pipefail
            test ! -e /srv/tftp/upload.txt
            cmp /src/tests/fixtures/download.txt /srv/tftp/overwrite.txt
        '
        deadline=$((SECONDS + IDLE_TIMEOUT))
        while :; do
            state=$(docker exec "$server" systemctl show atftpd.service --property=ActiveState --value)
            [[ $state == inactive ]] && break
            (( SECONDS < deadline )) || { printf '%s\n' '[FAIL] server did not exit after idle timeout' >&2; return 1; }
            sleep 0.2
        done
        run docker exec "$server" systemctl is-active atftpd.socket
        download "$client" "$server"
        run docker exec "$server" make -C /src service.check
        run docker exec "$server" make -C /src sd_stop
        run docker exec "$client" /bin/bash -p -c '
            set -euo pipefail
            status=0
            timeout 5 /src/tests/client.bash --host "$1" --remote validation.txt \
                --expected /src/tests/fixtures/download.txt || status=$?
            test "$status" -ne 0
            printf "%s\n" "PASS: stopped peer cannot serve downloads"
        ' peer "$server"
        run docker exec "$server" make -C /src sd_start
        download "$client" "$server"
        run docker exec "$server" make -C /src sd_restart
        download "$client" "$server"
    done
    run docker restart "${CONTAINERS[@]}"
    for index in "${!VERSIONS[@]}"; do
        server=$PREFIX-${VERSIONS[$index]}
        client=$PREFIX-${VERSIONS[$((1-index))]}
        ready "$server"
        ready "$client"
        run docker exec "$server" systemctl is-enabled atftpd.socket
        run docker exec "$server" systemctl is-active atftpd.socket
        run docker exec "$server" make -C /src service.check
        download "$client" "$server"
    done
}

main "$@"
