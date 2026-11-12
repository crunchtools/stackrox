# stackrox Constitution

> **Version:** 1.0.0
> **Ratified:** 2026-11-12
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.41.0
> **Profile:** Container Image

## What this image provides

[StackRox](https://github.com/stackrox/stackrox) Scanner V4, the
claircore-based image scanner inside StackRox / Red Hat Advanced Cluster
Security, packaged to run **standalone**: one container beside a Postgres, no
Central, no Kubernetes. It scans any OCI image, including Red Hat Hardened
Images (Hummingbird), which claircore detects as `dist=hummingbird` and matches
against Red Hat's CSAF VEX data.

## Base image and packages

- Build stage: `quay.io/hummingbird/go:1.26-builder` compiles `scanner` and
  `scannerctl` from the upstream release tarball (`CGO_ENABLED=0`).
- Runtime: `registry.access.redhat.com/ubi10/ubi-minimal` with `openssl`,
  `bash` and `ca-certificates`. Not distroless: the cert and entrypoint
  scripts are bash and openssl, as upstream's own image uses a bash entrypoint.
- Runs as UID 65532. Database: `quay.io/hummingbird/postgresql:18`.

## Project-unique requirements

- **The version is upstream's.** `ARG STACKROX_VERSION` pins the StackRox
  release, the image label and the git tag carry the same number (`v5.0.0`
  ships 5.0.0), and `CHANGELOG.md` sections are upstream versions.
  Packaging-only fixes land on `main` and ship in the weekly rebuild; the next
  tag is the next upstream release. `VULN_BUNDLE` pins the bundle stream that
  release reads (`v4` for 5.0.x) and the build fails if upstream disagrees.
- **Dev build flavour, by necessity.** Upstream release builds (`-tags release`)
  route every matcher download through Central. This image builds without that
  tag so the matcher fetches the public bundle itself; the remaining
  dev-vs-release differences are GC minimums and feature-flag mutability.
  The bundle URL is pinned explicitly in the rendered config, never the
  `dev` default.
- **The vulnerability data is never baked into the image.** The matcher
  downloads the bundle on first start, keeps it in Postgres, and polls for a
  newer one every ~5 minutes (plus jitter) with `If-Modified-Since`.
- **The client identity is Central.** Scanner V4 authorizes gRPC callers by
  certificate subject and accepts only Central and Sensors. `stackrox-certs`
  mints a private CA, a `SCANNER_V4_SERVICE` server cert and a
  `CENTRAL_SERVICE` client cert; the CA key never leaves the volume.
- **No plaintext secret in the config.** The DB password arrives as a file
  (`SCANNER_DB_PASSWORD_FILE`) or as an EnvironmentFile-delivered variable that
  the entrypoint writes to a 0600 temp file; the rendered `config.yaml` holds
  only the file path.
