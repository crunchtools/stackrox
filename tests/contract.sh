#!/usr/bin/env bash
# Contract: the digest holds what it promises.
#   - scanner and scannerctl present; scanner reports the pinned version and v4 bundle
#   - stackrox-certs mints a CA and the two identities Scanner V4 checks, idempotently
#   - runs as 65532, and the image carries no RHSM leftovers
#
#   IMAGE=quay.io/crunchtools/stackrox@sha256:... tests/contract.sh
set -euo pipefail

: "${IMAGE:?IMAGE must be set}"
want=$(sed -n 's/^ARG STACKROX_VERSION=//p' Containerfile | head -1)

podman run --rm "$IMAGE" bash -euo pipefail -c '
    command -v scanner >/dev/null
    command -v scannerctl >/dev/null
    for s in stackrox-certs stackrox-entrypoint stackrox-scan; do
        test -x "/usr/local/bin/$s"
    done
    test "$(id -u)" = 65532
    ! ls /etc/pki/entitlement/*.pem >/dev/null 2>&1
    ! test -e /etc/rhsm/rhsm.conf.kickstart
'

ver=$(podman run --rm "$IMAGE" scanner -version)
echo "scanner -version: $ver"
[[ "$ver" == "$want v4" ]] || { echo "contract: want '$want v4'" >&2; exit 1; }

podman run --rm "$IMAGE" bash -euo pipefail -c '
    d=$(mktemp -d)
    stackrox-certs "$d"
    a=$(sha256sum "$d"/ca.pem "$d"/scanner/cert.pem "$d"/client/cert.pem)
    stackrox-certs "$d"
    test "$a" = "$(sha256sum "$d"/ca.pem "$d"/scanner/cert.pem "$d"/client/cert.pem)"
    openssl verify -CAfile "$d/ca.pem" "$d/scanner/cert.pem" "$d/client/cert.pem"
    openssl x509 -in "$d/scanner/cert.pem" -noout -subject | grep -q "OU *= *SCANNER_V4_SERVICE, CN *= *SCANNER_V4_SERVICE: Scanner V4"
    openssl x509 -in "$d/client/cert.pem" -noout -subject | grep -q "OU *= *CENTRAL_SERVICE, CN *= *CENTRAL_SERVICE: Central"
    openssl x509 -in "$d/scanner/cert.pem" -noout -ext subjectAltName | grep -q "scanner-v4.stackrox"
    test "$(stat -c %a "$d/ca-key.pem")" = 600
'
echo "contract: ok"
