# Shared assertions and command execution for isolated systemd tests.

set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unset BASH_ENV ENV

TEST_ROOT=$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
readonly TEST_ROOT
# The sourced test scripts use this fixture path.
# shellcheck disable=SC2034
readonly FIXTURE="$TEST_ROOT/tests/fixtures/download.txt"
readonly COMMAND_TIMEOUT=60
declare TEST_TOTAL=0 TEST_PASSED=0 TEST_FAILED=0 RUN_STATUS=0 RUN_OUTPUT='' WORKSPACE=''
cd -- "$TEST_ROOT"

function require {
    local message=$1
    shift
    TEST_TOTAL=$((TEST_TOTAL + 1))
    if "$@"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '[PASS] %s\n' "$message"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '[FAIL] %s\n' "$message" >&2
        exit 1
    fi
}

function capture {
    RUN_STATUS=0
    RUN_OUTPUT=$(timeout "$COMMAND_TIMEOUT" "$@" 2>&1) || RUN_STATUS=$?
    if [[ -n $WORKSPACE ]]; then
        {
            printf 'Command:'
            printf ' %q' "$@"
            printf '\n%s\nExit: %s\n' "$RUN_OUTPUT" "$RUN_STATUS"
        } >> "$WORKSPACE/commands.log"
    fi
}

function run {
    capture "$@"
    if (( RUN_STATUS != 0 )); then
        printf '%s\n' "$RUN_OUTPUT" >&2
        printf '[ABORT] Command exited %s:' "$RUN_STATUS" >&2
        printf ' %q' "$@" >&2
        printf '\n' >&2
        exit 1
    fi
}

function rejected {
    local message=$1 marker=$2
    shift 2
    capture "$@"
    if (( RUN_STATUS == 0 )) || [[ $RUN_OUTPUT != *"$marker"* ]]; then
        printf '%s\n' "$RUN_OUTPUT" >&2
    fi
    require "$message" test "$RUN_STATUS" -ne 0
    require "$message reports the failed condition" test "${RUN_OUTPUT#*"$marker"}" != "$RUN_OUTPUT"
}

function reset_units {
    run systemctl reset-failed atftpd.service atftpd.socket
}

function finish {
    local status=$1
    printf 'Tests: %s total, %s passed, %s failed\n' "$TEST_TOTAL" "$TEST_PASSED" "$TEST_FAILED"
    if (( status != 0 || TEST_FAILED != 0 )); then
        printf '[ABORT] Test execution is incomplete; workspace retained: %s\n' "$WORKSPACE" >&2
    elif [[ ${KEEP_WORKSPACE:-0} == 1 ]]; then
        printf 'Workspace retained: %s\n' "$WORKSPACE"
    elif [[ -n $WORKSPACE ]]; then
        rm -rf -- "$WORKSPACE"
    fi
}
