# stackrox — StackRox Scanner V4 running standalone, with no Central.
#
# Upstream ships Scanner V4 as a component of StackRox / Red Hat Advanced Cluster
# Security: release builds fetch vulnerability data only through Central, and the
# gRPC API only answers clients that present a Central identity. This image
# builds the same 5.0.0 source WITHOUT the `release` build tag, so the matcher
# fetches the public bundle from definitions.stackrox.io itself, and ships the
# scripts that mint a private CA, a scanner server cert and a Central-identity
# client cert so `stackrox-scan IMAGE` works out of the box.
#
# The version is upstream's: tag v5.0.0 ships StackRox 5.0.0.

ARG STACKROX_VERSION=5.0.0

FROM quay.io/hummingbird/go:1.26-builder AS build

ARG STACKROX_VERSION
# The vulnerability bundle stream this scanner reads (scanner/VULNERABILITY_VERSION
# in the upstream tree). The build checks it matches.
ARG VULN_BUNDLE=v4

WORKDIR /src
# The builder ships git and curl but no tar.
RUN dnf install -y tar gzip && dnf clean all
RUN set -eux; \
    curl -sSfL -o /tmp/stackrox.tgz \
        "https://github.com/stackrox/stackrox/archive/refs/tags/${STACKROX_VERSION}.tar.gz"; \
    tar -xzf /tmp/stackrox.tgz --strip-components=1; \
    rm -f /tmp/stackrox.tgz; \
    test "$(cat scanner/VULNERABILITY_VERSION)" = "${VULN_BUNDLE}"

# The version variables upstream fills from status.sh (the //XDef markers in
# scanner/internal/version and pkg/version/internal). No `release` tag: that is
# what lets the matcher reach definitions.stackrox.io directly.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    ldflags="-s -w \
      -X github.com/stackrox/rox/scanner/internal/version.Version=${STACKROX_VERSION} \
      -X github.com/stackrox/rox/scanner/internal/version.VulnerabilityVersion=${VULN_BUNDLE} \
      -X github.com/stackrox/rox/pkg/version/internal.MainVersion=${STACKROX_VERSION}"; \
    CGO_ENABLED=0 go build -trimpath -ldflags "$ldflags" -o /out/scanner ./scanner/cmd/scanner; \
    CGO_ENABLED=0 go build -trimpath -ldflags "$ldflags" -o /out/scannerctl ./scanner/cmd/scannerctl; \
    /out/scanner -version

FROM registry.access.redhat.com/ubi10/ubi-minimal:latest

ARG STACKROX_VERSION

LABEL maintainer="fatherlinux <scott.mccarty@crunchtools.com>"
LABEL name="stackrox" \
      version="${STACKROX_VERSION}" \
      description="StackRox Scanner V4 ${STACKROX_VERSION}, standalone: an image scanner that understands Red Hat Hardened Images (Hummingbird), with no Central."
LABEL org.opencontainers.image.source="https://github.com/crunchtools/stackrox"
LABEL org.opencontainers.image.version="${STACKROX_VERSION}"
LABEL org.opencontainers.image.licenses="Apache-2.0 AND AGPL-3.0-or-later"

# openssl mints the CA and certs; bash runs the scripts; ca-certificates lets the
# scanner reach registries, Red Hat's mapping files and the bundle over TLS.
RUN microdnf install -y openssl bash ca-certificates \
    && microdnf clean all \
    && rm -rf /var/cache/yum /var/cache/dnf

COPY --from=build /out/scanner /out/scannerctl /usr/local/bin/
COPY rootfs/ /

# Certs and the rendered config persist here. Vulnerability data lives in
# Postgres, never in the image.
ENV STACKROX_HOME=/var/lib/stackrox
RUN mkdir -p /var/lib/stackrox && chown 65532:65532 /var/lib/stackrox
VOLUME ["/var/lib/stackrox"]

USER 65532:65532
EXPOSE 8443 9443

ENTRYPOINT ["stackrox-entrypoint"]
