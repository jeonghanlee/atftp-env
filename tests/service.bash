#!/bin/bash -p

set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unset BASH_ENV ENV
# shellcheck source=tests/lib.bash
source "${BASH_SOURCE[0]%/*}/lib.bash"

readonly SERVICE=atftpd.service SOCKET=atftpd.socket
readonly UNIT_PATH=/etc/systemd/system
readonly READY_TIMEOUT=30
declare DOWNLOAD='' OVERWRITE='' UPLOAD='' PUBLICATION_READY=0

function cleanup {
    local status=$?
    systemctl stop "$SOCKET" "$SERVICE" >/dev/null 2>&1 || status=1
    if (( PUBLICATION_READY )); then rm -f -- "$DOWNLOAD" "$OVERWRITE" "$UPLOAD"; fi
    if (( TEST_FAILED != 0 )); then status=1; fi
    finish "$status"
    if (( status == 0 )); then
        printf '%s\n' 'PASS: real systemd socket activation and download-only transfers'
    fi
    exit "$status"
}

function main {
    local deadline state executable client user group data endpoint address port prefix pid uid gid entry value
    local -a fields=()
    require 'test runs on the isolated systemd host as root' test "$EUID" -eq 0
    WORKSPACE=$(mktemp -d /tmp/atftp-service.XXXXXX)
    trap cleanup EXIT
    deadline=$((SECONDS + READY_TIMEOUT))
    while :; do
        capture systemctl is-system-running
        state=$RUN_OUTPUT
        [[ $state == running || $state == degraded ]] && break
        require 'systemd becomes ready before the deadline' test "$SECONDS" -lt "$deadline"
        sleep 0.2
    done
    run systemctl show "$SERVICE" --property=User --value
    user=$RUN_OUTPUT
    run systemctl show "$SERVICE" --property=Group --value
    group=$RUN_OUTPUT
    run systemctl show "$SERVICE" --property=ReadOnlyPaths --value
    data=$RUN_OUTPUT
    executable=$(awk -F= '$1 == "ExecStart" {split($2, words, " "); print words[1]}' "$UNIT_PATH/$SERVICE")
    client=${executable%/sbin/*}/bin/atftp
    run systemctl show "$SOCKET" --property=Listen --value
    endpoint=${RUN_OUTPUT% (Datagram)}
    address=${endpoint%:*} port=${endpoint##*:}
    [[ $address != 0.0.0.0 ]] || address=127.0.0.1
    uid=$(id -u "$user")
    entry=$(getent group "$group")
    IFS=: read -r value value gid value <<< "$entry"
    require 'service user is unprivileged' test "$uid" -ne 0
    require 'service group is unprivileged' test "$gid" -ne 0
    run systemctl show "$SERVICE" --property=ProtectSystem --value
    require 'service filesystem is read-only' test "$RUN_OUTPUT" = strict
    require 'server executable is root-owned' test "$(stat -L -c '%u' "$executable")" -eq 0
    run "$client" --version
    require 'installed client version is 0.8.1' test "$RUN_OUTPUT" = 'atftp-0.8.1 (client)'
    run "$executable" --version
    require 'installed server version is 0.8.1' test "$RUN_OUTPUT" = 'atftp-0.8.1 (server)'
    prefix=${WORKSPACE##*/}
    DOWNLOAD=$data/$prefix-download OVERWRITE=$data/$prefix-overwrite UPLOAD=$data/$prefix-upload
    require 'test publication paths are unused' test ! -e "$DOWNLOAD"
    require 'overwrite probe path is unused' test ! -e "$OVERWRITE"
    require 'upload probe path is unused' test ! -e "$UPLOAD"
    PUBLICATION_READY=1
    install -m 644 "$FIXTURE" "$DOWNLOAD"
    install -m 666 "$FIXTURE" "$OVERWRITE"
    run systemctl stop "$SOCKET" "$SERVICE"
    run systemctl start "$SOCKET"
    run systemctl is-active "$SOCKET"
    require 'socket is active before the first request' test "$RUN_OUTPUT" = active
    capture systemctl is-active "$SERVICE"
    require 'service waits for socket activation' test "$RUN_OUTPUT" = inactive
    run "$client" --tftp-timeout 2 --get --remote-file "${DOWNLOAD##*/}" \
        --local-file "$WORKSPACE/received" "$address" "$port"
    require 'download matches the shipped fixture' cmp -s "$FIXTURE" "$WORKSPACE/received"
    run ./tests/client.bash --host "$address" --port "$port" --remote "${DOWNLOAD##*/}" \
        --expected "$FIXTURE" --client "$client"
    require 'operator client check verifies the published download' \
        test "${RUN_OUTPUT#*'[PASS] download content matches'}" != "$RUN_OUTPUT"
    run systemctl show "$SERVICE" --property=MainPID --value
    pid=$RUN_OUTPUT
    while read -r -a fields; do
        case "${fields[0]}" in
            Uid:) entry=$uid ;; Gid:) entry=$gid ;; *) continue ;;
        esac
        require 'process identity exposes all four IDs' test "${#fields[@]}" -eq 5
        for value in "${fields[@]:1}"; do
            require 'running server uses the configured identity' test "$value" = "$entry"
        done
    done < "/proc/$pid/status"
    rejected 'upload of a new file is rejected' 'error received from server' \
        "$client" --tftp-timeout 2 --put --remote-file "${UPLOAD##*/}" --local-file "$FIXTURE" "$address" "$port"
    require 'rejected upload creates no file' test ! -e "$UPLOAD"
    printf '%s\n' 'Upload must not replace server content.' > "$WORKSPACE/changed"
    rejected 'upload cannot overwrite a world-writable file' 'error received from server' \
        "$client" --tftp-timeout 2 --put --remote-file "${OVERWRITE##*/}" \
        --local-file "$WORKSPACE/changed" "$address" "$port"
    require 'rejected overwrite preserves the approved bytes' cmp -s "$FIXTURE" "$OVERWRITE"
    run systemctl stop "$SOCKET" "$SERVICE"
    capture systemctl is-active "$SOCKET"
    require 'stop deactivates the socket' test "$RUN_OUTPUT" = inactive
    capture systemctl is-active "$SERVICE"
    require 'stop deactivates the service' test "$RUN_OUTPUT" = inactive
    run systemctl start "$SOCKET"
    run "$client" --tftp-timeout 2 --get --remote-file "${DOWNLOAD##*/}" \
        --local-file "$WORKSPACE/received" "$address" "$port"
    require 'download works after restarting the socket' cmp -s "$FIXTURE" "$WORKSPACE/received"
}

main "$@"
