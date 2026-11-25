#!/usr/bin/env bash
# Boot gate: the image starts as production starts it — beside a Hummingbird
# Postgres in one pod, the password a podman secret mounted as a file — and the
# scanner's readiness endpoint answers 200 over its own TLS. Readiness is
# "database" (upstream default), so this does not wait for the ~15-minute
# vulnerability import.
#
# The pod has no network but its own loopback (--network none): nothing here
# reaches a registry, the bundle or any other service, and the matcher's bundle
# fetch fails and retries without touching readiness. With no published port,
# readiness is asked from inside the pod, by the image's own curl.
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
    podman secret rm "$pod-pw" >/dev/null 2>&1 || true
    exit "$status"
}
trap cleanup EXIT

printf '%s' "$pw" | podman secret create "$pod-pw" - >/dev/null
podman pod create --name "$pod" --network none >/dev/null
podman run -d --pod "$pod" --name "$pod-db" \
    --secret "$pod-pw,type=mount,target=/run/secrets/db-password" \
    -e POSTGRES_PASSWORD_FILE=/run/secrets/db-password "$DB_IMAGE" >/dev/null
podman run -d --pod "$pod" --name "$pod-scanner" \
    --secret "$pod-pw,type=mount,target=/run/secrets/db-password,uid=65532,mode=0400" \
    -e SCANNER_DB_PASSWORD_FILE=/run/secrets/db-password "$IMAGE" >/dev/null

deadline=$((SECONDS + TIMEOUT))
code=000
while (( SECONDS < deadline )); do
    if [[ "$(podman inspect -f '{{.State.Running}}' "$pod-scanner")" != true ]]; then
        echo "boot: scanner exited" >&2
        exit 1
    fi
    code=$(podman exec "$pod-scanner" curl -sk -o /dev/null -w '%{http_code}' \
        https://127.0.0.1:9443/health/readiness || true)
    if [[ "$code" == 200 ]]; then
        echo "boot: readiness 200 after ${SECONDS}s"
        exit 0
    fi
    sleep 3
done
echo "boot: readiness not 200 in ${TIMEOUT}s (last $code)" >&2
exit 1
