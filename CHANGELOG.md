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
  (Postgres host, port, user, database, password file) and starts the scanner.
- `stackrox-scan IMAGE`: scans one image against the running scanner and prints
  the JSON report.
- Boot gate (scanner + Hummingbird `postgresql:18` in a pod, readiness 200) and a
  contract test (version, bundle stream, cert identities).
