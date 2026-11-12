#!/usr/bin/env bash
# Boot gate: the image starts as production starts it — beside a Hummingbird
# Postgres in one pod — and the scanner's readiness endpoint answers 200 over
# its own TLS. Readiness is "database" (upstream default), so this does not wait
# for the ~15-minute vulnerability import.
#
#   IMAGE=quay.io/crunchtools/stackrox@sha256:... tests/boot.sh
set -euo pipefail

: "${IMAGE:?IMAGE must be set}"
DB_IMAGE=${DB_IMAGE:-quay.io/hummingbird/postgresql:18}
TIMEOUT=${TIMEOUT:-180}
pod=stackrox-boot-$$
pw=boot-only-not-a-secret

# shellcheck disable=SC2329  # invoked by the EXIT trap
cleanup() {
    status=$?
    if [[ $status -ne 0 ]]; then
        podman logs "$pod-scanner" 2>&1 | tail -40 || true
    fi
    podman pod rm -f "$pod" >/dev/null 2>&1 || true
    exit "$status"
}
trap cleanup EXIT

podman pod create --name "$pod" -p 127.0.0.1::9443 >/dev/null
podman run -d --pod "$pod" --name "$pod-db" \
    -e POSTGRES_PASSWORD="$pw" "$DB_IMAGE" >/dev/null
podman run -d --pod "$pod" --name "$pod-scanner" \
    -e SCANNER_DB_PASSWORD="$pw" "$IMAGE" >/dev/null

infra=$(podman pod inspect "$pod" --format '{{.InfraContainerID}}')
port=$(podman port "$infra" 9443/tcp | head -1 | sed 's/.*://')
[[ -n "$port" ]] || { echo "boot: no host port for 9443" >&2; exit 1; }

deadline=$((SECONDS + TIMEOUT))
code=000
while (( SECONDS < deadline )); do
    if [[ "$(podman inspect -f '{{.State.Running}}' "$pod-scanner")" != true ]]; then
        echo "boot: scanner exited" >&2
        exit 1
    fi
    code=$(curl -sk -o /dev/null -w '%{http_code}' "https://127.0.0.1:$port/health/readiness" || true)
    if [[ "$code" == 200 ]]; then
        echo "boot: readiness 200 after ${SECONDS}s"
        exit 0
    fi
    sleep 3
done
echo "boot: readiness not 200 in ${TIMEOUT}s (last $code)" >&2
exit 1
