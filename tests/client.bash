#!/bin/bash -p

set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unset BASH_ENV ENV
umask 077

readonly DEFAULT_CLIENT=/opt/atftp/bin/atftp
readonly COMMAND_TIMEOUT=20
declare HOST='' REMOTE='' EXPECTED='' CLIENT=$DEFAULT_CLIENT PORT=69 WORKSPACE=''

function fail {
    printf '[FAIL] %s\n' "$*" >&2
    exit 1
}

function usage {
    printf 'Usage: %s --host HOST --remote FILE --expected FILE [--client PATH] [--port PORT]\n' "$0"
}

function cleanup {
    [[ -z $WORKSPACE ]] || rm -rf -- "$WORKSPACE"
}

function main {
    local option output status=0 bytes digest
    while (( $# > 0 )); do
        option=$1
        case "$option" in
            -h|--help) usage; return ;;
            --host|--remote|--expected|--client|--port)
                (( $# >= 2 )) || fail "Missing value for $option"
                case "$option" in
                    --host) HOST=$2 ;; --remote) REMOTE=$2 ;; --expected) EXPECTED=$2 ;;
                    --client) CLIENT=$2 ;; --port) PORT=$2 ;;
                esac
                shift 2
                ;;
            *) fail "Unknown argument: $option" ;;
        esac
    done
    [[ -n $HOST && -n $REMOTE && -n $EXPECTED ]] || { usage; fail 'Required arguments are missing'; }
    [[ $REMOTE != /* && $REMOTE != . && /$REMOTE/ != *'/../'* ]] ||
        fail '--remote must be a relative published file path without ..'
    if [[ ! $PORT =~ ^[0-9]{1,5}$ ]] || (( 10#$PORT < 1 || 10#$PORT > 65535 )); then
        fail '--port must be between 1 and 65535'
    fi
    [[ -f $EXPECTED && -r $EXPECTED ]] || fail "Cannot read expected file: $EXPECTED"
    [[ -x $CLIENT ]] || fail "Cannot execute client: $CLIENT"
    WORKSPACE=$(mktemp -d /tmp/atftp-client.XXXXXX)
    trap cleanup EXIT
    output=$(timeout "$COMMAND_TIMEOUT" "$CLIENT" --tftp-timeout 2 --get \
        --remote-file "$REMOTE" --local-file "$WORKSPACE/received" "$HOST" "$PORT" 2>&1) || status=$?
    (( status == 0 )) || fail "client exited $status: $output"
    [[ -f $WORKSPACE/received ]] || fail 'Client did not produce a download'
    cmp -s -- "$EXPECTED" "$WORKSPACE/received" || fail 'download content differs from the expected file'
    bytes=$(wc -c < "$EXPECTED")
    read -r digest _ < <(sha256sum -- "$EXPECTED")
    printf '[PASS] download content matches; bytes=%s; sha256=%s\n' "${bytes//[[:space:]]/}" "$digest"
}

main "$@"
