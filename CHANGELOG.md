# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Versions
are upstream StackRox's: each release ships that StackRox version.

## [Unreleased]

## [5.0.0] - 2026-11-12

### Added
- StackRox Scanner V4 5.0.0 (indexer + matcher) built from the upstream release
  without the `release` tag, so it fetches the public `v4` vulnerability bundle
  directly and runs with no Central.
- `stackrox-certs`: mints a private CA, the `SCANNER_V4_SERVICE` server identity
  and the `CENTRAL_SERVICE` client identity Scanner V4 authorizes. Idempotent.
- `stackrox-entrypoint`: renders the scanner config from the environment
  (Postgres host, port, user, database) and starts the scanner. The password
  comes only from `SCANNER_DB_PASSWORD_FILE`, a mounted podman secret;
  `SCANNER_DB_PASSWORD` is refused.
- `stackrox-scan IMAGE`: scans one image against the running scanner and prints
  the JSON report.
- Boot gate (scanner + Hummingbird `postgresql:18` in a pod with no network but
  its loopback, the password a podman secret, readiness 200) and a contract test
  (version, bundle stream, cert identities).
- The build resolves no Go modules: `deps/go.mod` and `go.sum` are upstream
  5.0.0's with grype's flagged modules at their fixed releases, built with
  `-mod=readonly`, and the release tarball is checked against its sha256.
