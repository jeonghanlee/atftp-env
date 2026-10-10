#!/bin/bash -p

set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unset BASH_ENV ENV
shopt -s extglob

readonly COMMAND_TIMEOUT=20
readonly SYSTEMCTL=/usr/bin/systemctl
readonly BUSCTL=/usr/bin/busctl
readonly -a MOUNT_EXCEPTIONS=(ReadWritePaths BindPaths TemporaryFileSystem RootDirectory RootImage)
# Associative state is accessed through named references.
# shellcheck disable=SC2034
declare -A INSTALLED_SERVICE=() INSTALLED_SOCKET=() LIVE_SERVICE=() LIVE_SOCKET=()
declare -a SERVER_ARGUMENTS=()

function fail {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

function require_owned {
    local path=$1 metadata uid gid mode
    metadata=$(stat -L -c '%u %g %a' -- "$path") || fail "Cannot inspect $path"
    read -r uid gid mode <<< "$metadata"
    if (( uid != 0 || gid != 0 || (8#$mode & 022) != 0 )); then
        fail "$path must be root-owned and not group/world writable"
    fi
}

function check_program {
    local path=$1 resolved candidate
    resolved=$(readlink -e -- "$path") || fail "Cannot resolve program path $path"
    [[ -f $resolved && -x $resolved ]] || fail "Program path is not an executable regular file: $path"
    for candidate in "$path" "$resolved"; do
        while :; do
            require_owned "$candidate"
            [[ $candidate == / ]] && break
            candidate=${candidate%/*}
            [[ -n $candidate ]] || candidate=/
        done
    done
}

function read_unit {
    local path=$1 destination=$2 line section='' key value
    local -n parser_fields=$destination
    require_owned "$path"
    while IFS= read -r line || [[ -n ${line:-} ]]; do
        line=${line##+([[:space:]])}
        line=${line%%+([[:space:]])}
        case "$line" in
            ''|'#'*|';'*) continue ;;
            '['*']') section=${line:1:${#line}-2}; continue ;;
        esac
        [[ $section == Service || $section == Socket ]] || continue
        [[ $line == *=* ]] || fail "Invalid unit assignment in $path"
        key=${line%%=*}
        key=${key%%+([[:space:]])}
        [[ $key =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || fail "Invalid unit key in $path"
        value=${line#*=}
        value=${value##+([[:space:]])}
        [[ ! -v parser_fields[$key] ]] || fail "Duplicate unit assignment $key in $path"
        parser_fields["$key"]=$value
    done < "$path"
}

function expect {
    local destination=$1 key=$2 wanted=$3 label=$4 got
    local -n expected_fields=$destination
    got=${expected_fields[$key]:-}
    [[ $got == "$wanted" ]] || fail "$label $key: expected '$wanted', got '$got'"
}

function live_properties {
    local unit=$1 keys=$2 destination=$3 output line
    local -n live_fields=$destination
    output=$(timeout "$COMMAND_TIMEOUT" "$SYSTEMCTL" show "$unit" --property="$keys") ||
        fail "Cannot query $unit"
    while IFS= read -r line; do
        # The named reference updates the caller's property map.
        # shellcheck disable=SC2034
        [[ $line == *=* ]] && live_fields[${line%%=*}]=${line#*=}
    done <<< "$output"
}

function bus_property {
    local unit=$1 key=$2 lookup signature object
    lookup=$(timeout "$COMMAND_TIMEOUT" "$BUSCTL" call org.freedesktop.systemd1 \
        /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager GetUnit s "$unit") ||
        fail "Cannot locate $unit"
    read -r signature object <<< "$lookup"
    [[ $signature == o && $object == \"/org/freedesktop/systemd1/unit/*\" ]] ||
        fail 'Unexpected systemd unit lookup response'
    object=${object:1:${#object}-2}
    timeout "$COMMAND_TIMEOUT" "$BUSCTL" get-property org.freedesktop.systemd1 \
        "$object" org.freedesktop.systemd1.Service "$key"
}

function check_mount_exceptions {
    local destination=$1 label=$2 unit=${3:-} key value response signature count rest
    local -n mount_fields=$destination
    for key in "${MOUNT_EXCEPTIONS[@]}"; do
        value=${mount_fields[$key]:-}
        if [[ -n $unit && $value == '[unprintable]' ]]; then
            response=$(bus_property "$unit" "$key") || fail "Cannot query $unit $key"
            read -r signature count rest <<< "$response"
            [[ $signature == a* && $count =~ ^[0-9]+$ ]] || fail "Unexpected structured property $key"
            if (( count == 0 )); then value=''; fi
        fi
        [[ -z $value ]] || fail "$label $key must be empty"
    done
}

function process_start {
    local pid=$1 record
    local -a fields=()
    IFS= read -r record < "/proc/$pid/stat" || fail "Cannot inspect process $pid"
    read -r -a fields <<< "${record##*) }"
    printf '%s\n' "${fields[19]}"
}

function udp_endpoint {
    local address=${1%:*} port=${1#*:} byte_order
    read -r byte_order < <(printf '\001\000' | od -An -tu2)
    if [[ $byte_order == 1 ]]; then
        address=${address:6:2}${address:4:2}${address:2:2}${address:0:2}
    fi
    printf '%d.%d.%d.%d:%d\n' "0x${address:0:2}" "0x${address:2:2}" \
        "0x${address:4:2}" "0x${address:6:2}" "0x$port"
}

function check_socket_consumers {
    local expected_pid=$1 endpoint=$2 address descriptor fd pid
    local -a columns=()
    local -A inodes=()
    while read -r -a columns; do
        (( ${#columns[@]} > 9 )) || continue
        [[ ${columns[1]} =~ ^[0-9A-F]{8}:[0-9A-F]{4}$ ]] || continue
        address=$(udp_endpoint "${columns[1]}")
        [[ $address == "$endpoint" ]] && inodes[${columns[9]}]=1
    done < /proc/self/net/udp
    for fd in /proc/[0-9]*/fd/0; do
        descriptor=$(readlink -- "$fd" 2>/dev/null) || continue
        [[ $descriptor =~ ^socket:\[([0-9]+)\]$ ]] || continue
        [[ -v inodes[${BASH_REMATCH[1]}] ]] || continue
        pid=${fd#/proc/}
        pid=${pid%%/*}
        [[ $pid == "$expected_pid" ]] || fail "Unexpected running server socket consumer: PID $pid"
    done
}

function check_process {
    local pid=$1 user=$2 group=$3 data=$4 endpoint=$5 identity current descriptor inode bound=''
    local uid gid entry key covering='' covering_options='' path options index executable
    local -a actual=() fields=()
    identity=$(process_start "$pid")
    mapfile -d '' -t actual < "/proc/$pid/cmdline"
    (( ${#actual[@]} == ${#SERVER_ARGUMENTS[@]} )) ||
        fail 'running server arguments differ from the configured OPTIONS'
    for index in "${!actual[@]}"; do
        [[ ${actual[$index]} == "${SERVER_ARGUMENTS[$index]}" ]] ||
            fail 'running server arguments differ from the configured OPTIONS'
    done
    [[ /proc/$pid/exe -ef ${SERVER_ARGUMENTS[0]} ]] ||
        fail 'running server executable differs from the installed program; restart the service'
    executable=$(readlink -e -- "/proc/$pid/exe") || fail 'Cannot resolve running server executable'
    check_program "$executable"
    descriptor=$(readlink -- "/proc/$pid/fd/0") || fail 'Cannot inspect running server standard input'
    [[ $descriptor =~ ^socket:\[([0-9]+)\]$ ]] || fail 'running server standard input is not a socket'
    inode=${BASH_REMATCH[1]}
    while read -r -a fields; do
        if (( ${#fields[@]} > 9 )) && [[ ${fields[9]} == "$inode" ]]; then
            bound=$(udp_endpoint "${fields[1]}")
            break
        fi
    done < "/proc/$pid/net/udp"
    [[ $bound == "$endpoint" ]] || fail "running server socket endpoint: expected $endpoint, got $bound"
    uid=$(id -u "$user")
    entry=$(getent group "$group")
    IFS=: read -r key key gid key <<< "$entry"
    while read -r -a fields; do
        key=${fields[0]}
        fields=("${fields[@]:1}")
        case "$key" in
            Uid:) entry=$uid ;;
            Gid:) entry=$gid ;;
            *) continue ;;
        esac
        (( ${#fields[@]} == 4 )) || fail "Invalid running server $key"
        for current in "${fields[@]}"; do
            [[ $current == "$entry" ]] || fail "running server $key expected $entry, got $current"
        done
    done < "/proc/$pid/status"
    data=$(readlink -e -- "$data")
    while read -r -a fields; do
        printf -v path '%b' "${fields[4]}"
        options=${fields[5]}
        if [[ $data == "$path" || $data == "${path%/}/"* ]]; then
            if (( ${#path} > ${#covering} )); then
                covering=$path
                covering_options=$options
            fi
        elif [[ $path == "${data%/}/"* ]]; then
            [[ ,$options, == *,ro,* ]] || fail "running server writable mount: $path"
        fi
    done < "/proc/$pid/mountinfo"
    [[ -n $covering ]] || fail "running server has no mount covering $data"
    [[ ,$covering_options, == *,ro,* ]] || fail "running server writable mount: $covering"
    current=$(process_start "$pid")
    [[ $current == "$identity" ]] || fail 'running server identity changed during verification; retry the check'
    printf '%s\n' 'PASS: running server UID/GID and read-only data mounts'
}

function main {
    local service socket user group data install conf endpoint live options line assignment='' key value
    local unit socket_unit default_service response expected pid current
    local -a words=()
    (( $# == 10 )) || fail 'Usage: check-service.bash service socket user group data install conf endpoint live options'
    service=$1 socket=$2 user=$3 group=$4 data=$5 install=$6 conf=$7 endpoint=$8 live=$9 options=${10}
    unit=${service##*/}
    socket_unit=${socket##*/}
    [[ $live == 0 || $live == 1 ]] || fail 'live must be 0 or 1'
    read -r -a words <<< "$options"
    if (( ${#words[@]} == 0 )) || [[ ${words[-1]} != "$data" ]]; then
        fail 'configured OPTIONS must end with the approved data directory'
    fi
    SERVER_ARGUMENTS=("$install/sbin/atftpd" "${words[@]}")
    for key in "$install/bin/atftp" "$install/sbin/atftpd" "$install/atftpd.bash"; do
        check_program "$key"
    done
    require_owned "$install/$conf"
    while IFS= read -r line || [[ -n ${line:-} ]]; do
        line=${line##+([[:space:]])}
        line=${line%%+([[:space:]])}
        [[ -z $line || $line == '#'* ]] && continue
        [[ -z $assignment ]] || fail 'installed configuration must contain one OPTIONS assignment'
        assignment=$line
    done < "$install/$conf"
    if [[ $assignment != "OPTIONS=\"$options\"" && $assignment != "OPTIONS='$options'" ]]; then
        fail 'installed OPTIONS differ from the site configuration'
    fi
    read_unit "$service" INSTALLED_SERVICE
    read_unit "$socket" INSTALLED_SOCKET
    for key in User Group ProtectSystem ReadOnlyPaths NoNewPrivileges PrivateTmp ProtectHome StandardInput; do
        case "$key" in
            User) value=$user ;; Group) value=$group ;; ProtectSystem) value=strict ;;
            ReadOnlyPaths) value=$data ;; StandardInput) value=socket ;; *) value=yes ;;
        esac
        expect INSTALLED_SERVICE "$key" "$value" "$service"
    done
    expect INSTALLED_SERVICE ExecStart "$install/sbin/atftpd \$OPTIONS" "$service"
    expect INSTALLED_SERVICE EnvironmentFile "$install/$conf" "$service"
    check_mount_exceptions INSTALLED_SERVICE "$service"
    expect INSTALLED_SOCKET ListenDatagram "$endpoint" "$socket"
    expect INSTALLED_SOCKET Accept no "$socket"
    default_service=${socket_unit%.socket}.service
    [[ ${INSTALLED_SOCKET[Service]:-$default_service} == "$unit" ]] ||
        fail 'installed socket Service differs from the approved service'
    if [[ $live == 1 ]]; then
        live_properties "$socket_unit" Listen,Accept,NeedDaemonReload,Triggers LIVE_SOCKET
        expect LIVE_SOCKET Listen "$endpoint (Datagram)" 'live socket'
        expect LIVE_SOCKET Accept no 'live socket'
        expect LIVE_SOCKET NeedDaemonReload no 'live socket'
        expect LIVE_SOCKET Triggers "$unit" 'live socket'
        response=$(bus_property "$unit" ExecStart) || fail 'Cannot inspect live service ExecStart'
        expected="a(sasbttttuii) 1 \"$install/sbin/atftpd\" 2 \"$install/sbin/atftpd\" \"\$OPTIONS\" "
        [[ $response == "$expected"* ]] || fail 'live service ExecStart differs from the approved command'
        response=$(bus_property "$unit" EnvironmentFiles) || fail 'Cannot inspect live service EnvironmentFiles'
        [[ $response == "a(sb) 1 \"$install/$conf\" false" ]] ||
            fail 'live service EnvironmentFiles differ from the approved configuration'
        live_properties "$unit" \
            User,Group,ProtectSystem,ReadOnlyPaths,NoNewPrivileges,PrivateTmp,ProtectHome,StandardInput,ReadWritePaths,BindPaths,TemporaryFileSystem,RootDirectory,RootImage,NeedDaemonReload,MainPID,ActiveState \
            LIVE_SERVICE
        for key in User Group ProtectSystem ReadOnlyPaths NoNewPrivileges PrivateTmp ProtectHome StandardInput; do
            expect LIVE_SERVICE "$key" "${INSTALLED_SERVICE[$key]}" 'live service'
        done
        expect LIVE_SERVICE NeedDaemonReload no 'live service'
        check_mount_exceptions LIVE_SERVICE 'live service' "$unit"
        pid=${LIVE_SERVICE[MainPID]:-0}
        [[ $pid =~ ^[0-9]+$ ]] || fail 'Invalid service MainPID'
        if (( pid != 0 )); then
            check_process "$pid" "$user" "$group" "$data" "$endpoint"
            current=$(timeout "$COMMAND_TIMEOUT" "$SYSTEMCTL" show "$unit" --property=MainPID --value)
            [[ $current == "$pid" ]] || fail 'running server changed during verification; retry the check'
        else
            [[ ${LIVE_SERVICE[ActiveState]:-} == inactive || ${LIVE_SERVICE[ActiveState]:-} == failed ]] ||
                fail 'service is transitioning without a MainPID; retry the check'
        fi
        check_socket_consumers "$pid" "$endpoint"
    fi
    printf '%s\n' 'PASS: installed unit identity and download-only policy'
}

main "$@"
