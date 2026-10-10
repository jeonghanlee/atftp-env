#!/bin/bash -p

set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unset BASH_ENV ENV
# shellcheck source=tests/lib.bash
source "${BASH_SOURCE[0]%/*}/lib.bash"

readonly UNIT_ROOT=/etc/systemd/system
readonly SERVICE=$UNIT_ROOT/atftpd.service SOCKET=$UNIT_ROOT/atftpd.socket
readonly DROPIN=$UNIT_ROOT/atftpd.service.d/90-atftp-test.conf
readonly SOCKET_DROPIN=$UNIT_ROOT/atftpd.socket.d/90-atftp-test.conf
readonly ALTERNATE=$UNIT_ROOT/atftp-installation-test.service
readonly CONFIG=/opt/atftp/atftpd.conf PROGRAM=/opt/atftp/sbin/atftpd
readonly DATA=/srv/tftp/atftp-installation-test
readonly WRITE_DIR=/srv/tftp/atftp-write-test
readonly WRITE_FILE=$WRITE_DIR/content
declare SERVER_MOVED=0

function download {
    run ./tests/client.bash --host 127.0.0.1 --remote "$1" --expected "$2" --port "${3:-69}"
}

function check_rejected {
    rejected "$1" "$2" make service.check "${@:3}"
}

function cleanup {
    local status=$?
    if [[ -f $WORKSPACE/service ]]; then
        [[ ! -f $SERVICE ]] || cp "$WORKSPACE/service" "$SERVICE"
        [[ ! -f $SOCKET ]] || cp "$WORKSPACE/socket" "$SOCKET"
        [[ ! -f $CONFIG ]] || cp "$WORKSPACE/config" "$CONFIG"
    fi
    rm -f -- "$DROPIN" "$SOCKET_DROPIN"
    systemctl daemon-reload >/dev/null 2>&1 || status=1
    systemctl stop atftpd.socket atftpd.service >/dev/null 2>&1 || status=1
    if [[ -f $ALTERNATE ]]; then
        systemctl stop "${ALTERNATE##*/}" >/dev/null 2>&1 || status=1
        rm -f -- "$ALTERNATE"
        systemctl daemon-reload >/dev/null 2>&1 || status=1
    fi
    if (( SERVER_MOVED )); then
        rm -f -- "$PROGRAM"
        mv "$WORKSPACE/server-original" "$PROGRAM"
    fi
    rm -f -- "$DATA" "$WRITE_FILE"
    [[ ! -d $WRITE_DIR ]] || rmdir -- "$WRITE_DIR"
    if (( TEST_FAILED != 0 )); then status=1; fi
    finish "$status"
    if (( status == 0 )); then
        printf '%s\n' 'PASS: installed-policy and removal-failure regressions'
    fi
    exit "$status"
}

function main {
    local before after key value pid options
    local -a fields=()
    require 'installation regressions run as root on a dedicated host' test "$EUID" -eq 0
    for value in "$DROPIN" "$SOCKET_DROPIN" "$ALTERNATE" "$DATA" "$WRITE_DIR"; do
        require 'test paths are unused' test ! -e "$value"
    done
    WORKSPACE=$(mktemp -d /var/lib/atftp-installation.XXXXXX)
    chmod 755 "$WORKSPACE"
    cp "$SERVICE" "$WORKSPACE/service"
    cp "$SOCKET" "$WORKSPACE/socket"
    cp "$CONFIG" "$WORKSPACE/config"
    trap cleanup EXIT
    run make help
    require 'help exposes service preparation' test "${RUN_OUTPUT#*service.setup}" != "$RUN_OUTPUT"
    require 'help exposes service verification' test "${RUN_OUTPUT#*service.check}" != "$RUN_OUTPUT"
    require 'help excludes variable assignments' test "${RUN_OUTPUT#*SRC_TAG}" = "$RUN_OUTPUT"
    run make service.check
    install -m 644 "$FIXTURE" "$DATA"
    reset_units
    options=$(sed -n 's/^OPTIONS="\(.*\)"$/\1/p' "$WORKSPACE/config")
    printf "OPTIONS='%s'\n" "$options" > "$CONFIG"
    run make sd_start
    download "${DATA##*/}" "$FIXTURE"
    run make service.check
    require 'single-quoted options match the real running arguments' \
        test "${RUN_OUTPUT#*'PASS: running server UID/GID'}" != "$RUN_OUTPUT"
    run make sd_stop
    cp "$WORKSPACE/config" "$CONFIG"
    reset_units
    sed 's|/srv/tftp|/etc|g' "$WORKSPACE/config" > "$CONFIG"
    check_rejected 'installed check rejects a different data root' 'installed OPTIONS'
    run make sd_start
    download hostname /etc/hostname
    cp "$WORKSPACE/config" "$CONFIG"
    check_rejected 'live check rejects retained data-root arguments' 'running server arguments'
    run make sd_stop
    reset_units
    mkdir -p "${SOCKET_DROPIN%/*}"
    printf '[Socket]\nListenDatagram=\nListenDatagram=0.0.0.0:1069\n' > "$SOCKET_DROPIN"
    run make sd_start
    download "${DATA##*/}" "$FIXTURE" 1069
    check_rejected 'live check rejects a socket port override' 'live socket Listen'
    rm "$SOCKET_DROPIN"
    run make sd_reload
    download "${DATA##*/}" "$FIXTURE" 1069
    check_rejected 'live check rejects a retained socket endpoint' 'running server socket endpoint'
    run make sd_restart
    download "${DATA##*/}" "$FIXTURE"
    run make service.check
    require 'restart restores the approved process and socket' \
        test "${RUN_OUTPUT#*'PASS: running server UID/GID'}" != "$RUN_OUTPUT"
    run make sd_stop
    reset_units

    cp "$WORKSPACE/socket" "$SOCKET"
    printf '\n# Pending socket configuration verification.\n' >> "$SOCKET"
    check_rejected 'live check rejects pending socket changes' 'live socket NeedDaemonReload'
    cp "$WORKSPACE/socket" "$SOCKET"
    run make sd_reload
    sed -e 's|ProtectSystem=strict|ProtectSystem=no|' -e '/^ReadOnlyPaths=/d' \
        -e 's|After=network.target atftpd.socket|After=network.target atftpd.socket atftpd.service|' \
        "$WORKSPACE/service" > "$ALTERNATE"
    sed 's|Service=atftpd.service|Service=atftp-installation-test.service|' "$WORKSPACE/socket" > "$SOCKET"
    check_rejected 'installed check rejects another socket service' 'installed socket Service' SYSTEMD_RELOAD=0
    cp "$WORKSPACE/socket" "$SOCKET"
    printf '[Socket]\nService=atftp-installation-test.service\n' > "$SOCKET_DROPIN"
    run make sd_reload
    check_rejected 'live check rejects a different triggered service' 'live socket Triggers'
    chmod 666 "$DATA"
    run make sd_start
    download "${DATA##*/}" "$FIXTURE"
    run /opt/atftp/bin/atftp --tftp-timeout 2 --put --remote-file "${DATA##*/}" \
        --local-file tests/client.bash 127.0.0.1 69
    require 'alternate service overwrites real published content' cmp -s tests/client.bash "$DATA"
    check_rejected 'active alternate service cannot pass verification' 'live socket Triggers'
    rm "$SOCKET_DROPIN"
    run make sd_reload
    check_rejected 'retained alternate process cannot pass after reload' 'Unexpected running server socket consumer'
    run make sd_stop
    run systemctl stop "${ALTERNATE##*/}"
    rm "$ALTERNATE"
    run make sd_reload
    install -m 644 "$FIXTURE" "$DATA"
    reset_units

    cp -p "$PROGRAM" "$WORKSPACE/server-copy"
    mv "$PROGRAM" "$WORKSPACE/server-original"
    SERVER_MOVED=1
    ln -s "$WORKSPACE/server-copy" "$PROGRAM"
    chown atftp:atftp "$WORKSPACE/server-copy"
    check_rejected 'installed check rejects a non-root symlink target' 'must be root-owned'
    run make sd_start
    download "${DATA##*/}" "$FIXTURE"
    check_rejected 'active non-root executable cannot pass verification' 'must be root-owned'
    chown root:root "$WORKSPACE/server-copy"
    chmod 777 "$WORKSPACE/server-copy"
    check_rejected 'installed check rejects a writable symlink target' 'must be root-owned'
    chmod 755 "$WORKSPACE/server-copy"
    run make service.check
    require 'secure symlink targets retain valid runtime support' \
        test "${RUN_OUTPUT#*'PASS: running server UID/GID'}" != "$RUN_OUTPUT"
    rm "$PROGRAM"
    mv "$WORKSPACE/server-original" "$PROGRAM"
    SERVER_MOVED=0
    check_rejected 'live check rejects a different executable inode' 'running server executable'
    run make sd_restart
    download "${DATA##*/}" "$FIXTURE"
    run make service.check
    run make sd_stop
    reset_units

    mkdir -p "${DROPIN%/*}"
    # The unit retains systemd's OPTIONS expansion.
    # shellcheck disable=SC2016
    printf '[Service]\nExecStart=\nExecStart=/opt/atftp/sbin/atftpd $OPTIONS /etc\n' > "$DROPIN"
    run make sd_reload
    check_rejected 'live check rejects another command' 'live service ExecStart'
    printf '[Service]\nEnvironmentFile=\nEnvironmentFile=/etc/atftp-test.conf\n' > "$DROPIN"
    run make sd_reload
    check_rejected 'live check rejects another configuration file' 'live service EnvironmentFiles'
    rm "$DROPIN"
    run make sd_reload
    while IFS='|' read -r before after; do
        sed "s|$before|$after|" "$WORKSPACE/service" > "$SERVICE"
        check_rejected "installed policy rejects $after" 'FAIL:'
        cp "$WORKSPACE/service" "$SERVICE"
    done <<'POLICIES'
User=atftp|User=root
Group=atftp|Group=root
ProtectSystem=strict|ProtectSystem=no
ReadOnlyPaths=/srv/tftp|ReadOnlyPaths=/opt
NoNewPrivileges=yes|NoNewPrivileges=no
PrivateTmp=yes|PrivateTmp=no
ProtectHome=yes|ProtectHome=no
POLICIES
    printf '[Service]\nUser=root\n' > "$DROPIN"
    run make sd_reload
    check_rejected 'live policy rejects a root override' 'live service User'
    rm "$DROPIN"
    run make sd_reload
    run make service.check
    mkdir "$WRITE_DIR"
    install -m 666 "$FIXTURE" "$WRITE_FILE"
    printf '\nReadWritePaths=%s\n' "$WRITE_DIR" >> "$SERVICE"
    check_rejected 'installed policy rejects a writable mount' 'ReadWritePaths must be empty'
    cp "$WORKSPACE/service" "$SERVICE"
    for key in ReadWritePaths BindPaths TemporaryFileSystem RootDirectory RootImage; do
        case "$key" in
            BindPaths) value=$WRITE_DIR:$WRITE_DIR ;;
            TemporaryFileSystem) value=$WRITE_DIR:rw ;;
            RootDirectory) value=/srv/tftp ;;
            RootImage) value=/tmp/atftp-test-image ;;
            *) value=$WRITE_DIR ;;
        esac
        printf '[Service]\n%s=%s\n' "$key" "$value" > "$DROPIN"
        run make sd_reload
        check_rejected "live policy rejects $key" "$key must be empty"
    done
    printf '[Service]\nReadWritePaths=%s\n' "$WRITE_DIR" > "$DROPIN"
    run make sd_start
    download "${WRITE_DIR##*/}/content" "$FIXTURE"
    run /opt/atftp/bin/atftp --tftp-timeout 2 --put --remote-file "${WRITE_DIR##*/}/content" \
        --local-file tests/client.bash 127.0.0.1 69
    require 'writable override changes real server content' cmp -s tests/client.bash "$WRITE_FILE"
    rm "$DROPIN"
    run make sd_reload
    check_rejected 'live check rejects retained writable mounts' 'running server writable mount'
    run make sd_restart
    download "${WRITE_DIR##*/}/content" tests/client.bash
    run make service.check
    run make sd_stop
    reset_units
    sed -e 's/User=atftp/User=root/' -e 's/Group=atftp/Group=root/' "$WORKSPACE/service" > "$SERVICE"
    run make sd_start
    download "${DATA##*/}" "$FIXTURE"
    run systemctl show atftpd.service --property=MainPID --value
    pid=$RUN_OUTPUT
    while read -r -a fields; do
        case "${fields[0]}" in Uid:|Gid:) ;; *) continue ;; esac
        for value in "${fields[@]:1}"; do
            require 'identity probe runs a real root server' test "$value" -eq 0
        done
    done < "/proc/$pid/status"
    cp "$WORKSPACE/service" "$SERVICE"
    run make sd_reload
    check_rejected 'live check rejects retained root identity' 'running server Uid'
    run make sd_restart
    download "${DATA##*/}" "$FIXTURE"
    run make service.check
    run make sd_stop
    printf '\n# Pending configuration verification.\n' >> "$SERVICE"
    check_rejected 'live check rejects pending service changes' 'NeedDaemonReload'
    cp "$WORKSPACE/service" "$SERVICE"
    run make sd_reload
    sed '/^\[Unit\]/a RefuseManualStop=yes' "$WORKSPACE/service" > "$SERVICE"
    sed '/^\[Unit\]/a RefuseManualStop=yes' "$WORKSPACE/socket" > "$SOCKET"
    run make sd_start
    download "${DATA##*/}" "$FIXTURE"
    capture make sd_stop
    require 'stop reports real systemd refusal' test "$RUN_STATUS" -ne 0
    capture make uninstall
    require 'uninstall aborts on stop refusal' test "$RUN_STATUS" -ne 0
    for value in "$PROGRAM" "$SERVICE" "$SOCKET"; do
        require 'failed uninstall preserves installed files' test -f "$value"
    done
    run systemctl is-enabled atftpd.socket
    require 'failed uninstall preserves boot enablement' test "$RUN_OUTPUT" = enabled
    cp "$WORKSPACE/service" "$SERVICE"
    cp "$WORKSPACE/socket" "$SOCKET"
    run make sd_reload
    run make sd_stop
    for value in atftpd.service atftpd.socket; do
        run systemctl show "$value" --property=ActiveState --value
        require 'successful stop confirms inactive units' test "$RUN_OUTPUT" = inactive
    done
    run make uninstall
    for value in "$PROGRAM" "$SERVICE" "$SOCKET"; do
        require 'successful uninstall removes installed files' test ! -e "$value"
    done
    require 'uninstall preserves published content' cmp -s "$FIXTURE" "$DATA"
    run getent passwd atftp
    require 'uninstall preserves service identity' test -n "$RUN_OUTPUT"
    run make install
    run make service.check
    require 'reinstallation restores the verified service' test -x "$PROGRAM"
}

main "$@"
