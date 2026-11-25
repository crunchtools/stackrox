#!/usr/bin/env bash
# Entrypoint gate: every way of handing stackrox-entrypoint a bad password is
# refused, with its own message, before anything is written. No database is
# started: each case must fail before the scanner would reach one.
#
# For each case the image's entrypoint runs with a fresh volume as
# $STACKROX_HOME; it must exit nonzero, say why, and leave the volume empty (no
# certs, no rendered config.yaml).
#
#   IMAGE=quay.io/crunchtools/stackrox@sha256:... tests/entrypoint.sh
set -euo pipefail

: "${IMAGE:?IMAGE must be set}"
run=stackrox-entrypoint-$$
tmp=$(mktemp -d)
failed=0

# shellcheck disable=SC2329  # invoked by the EXIT trap
cleanup() {
    status=$?
    podman volume ls -q --filter "name=^$run-" | xargs -r podman volume rm -f >/dev/null 2>&1 || true
    rm -rf "$tmp"
    exit "$status"
}
trap cleanup EXIT

: >"$tmp/empty"
printf 'unreadable' >"$tmp/unreadable"
chmod 0600 "$tmp/unreadable"  # owned by this user, not the image's 65532

# expect NAME MESSAGE -- PODMAN-RUN-ARGS...
expect() {
    local name=$1 message=$2 vol="$run-$1" out rc=0 left
    shift 3
    podman volume create "$vol" >/dev/null
    # --timeout: an entrypoint that does not refuse starts the scanner, which
    # waits for a database forever; that is a failure, not a hang.
    out=$(podman run --rm --network none --timeout "${CASE_TIMEOUT:-60}" \
        -v "$vol:/var/lib/stackrox" "$@" "$IMAGE" 2>&1) || rc=$?
    left=$(podman run --rm --network none -v "$vol:/var/lib/stackrox:ro" --entrypoint find "$IMAGE" \
        /var/lib/stackrox -mindepth 1)
    if [[ $rc -eq 0 ]]; then
        echo "entrypoint: $name: exited 0" >&2; failed=1
    elif ! grep -qF "$message" <<<"$out"; then
        echo "entrypoint: $name: exited $rc without '$message':" >&2; echo "$out" >&2; failed=1
    elif [[ -n "$left" ]]; then
        echo "entrypoint: $name: refused, but wrote:" >&2; echo "$left" >&2; failed=1
    else
        echo "entrypoint: $name: refused (exit $rc), nothing written"
    fi
}

expect password-in-env "SCANNER_DB_PASSWORD is not read" -- \
    -e SCANNER_DB_PASSWORD=boot-only-not-a-secret
expect file-unset "SCANNER_DB_PASSWORD_FILE is not set" --
expect file-missing "is missing, unreadable or empty" -- \
    -e SCANNER_DB_PASSWORD_FILE=/run/secrets/db-password
expect file-empty "is missing, unreadable or empty" -- \
    -v "$tmp/empty:/run/secrets/db-password:ro,Z" -e SCANNER_DB_PASSWORD_FILE=/run/secrets/db-password
expect file-unreadable "is missing, unreadable or empty" -- \
    -v "$tmp/unreadable:/run/secrets/db-password:ro,Z" -e SCANNER_DB_PASSWORD_FILE=/run/secrets/db-password

exit "$failed"
