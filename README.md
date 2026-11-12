# stackrox

[StackRox](https://github.com/stackrox/stackrox) Scanner V4 **5.0.0**, running
standalone: a container image scanner beside a Postgres, with no Central and no
Kubernetes. It is the claircore-based scanner inside StackRox / Red Hat Advanced
Cluster Security, and it scans **Red Hat Hardened Images (Hummingbird)** —
detected as `dist=hummingbird` and matched against Red Hat's CSAF VEX data —
along with RHEL, UBI, Debian, Ubuntu, Alpine, language packages and the rest of
what claircore covers.

```
quay.io/crunchtools/stackrox:5.0.0
```

The image version is upstream's: `5.0.0` is StackRox 5.0.0.

## Quick start

```bash
podman pod create --name stackrox -p 127.0.0.1:8443:8443 -p 127.0.0.1:9443:9443
podman run -d --pod stackrox --name stackrox-db \
  -e POSTGRES_PASSWORD=change-me \
  -v stackrox-pg:/var/lib/postgresql/data \
  quay.io/hummingbird/postgresql:18
podman run -d --pod stackrox --name stackrox \
  -e SCANNER_DB_PASSWORD=change-me \
  -v stackrox-home:/var/lib/stackrox \
  quay.io/crunchtools/stackrox:5.0.0

# readiness answers in seconds; the first vulnerability import takes ~15 minutes
curl -sk https://127.0.0.1:9443/health/readiness

podman exec stackrox stackrox-scan registry.access.redhat.com/hi/go:latest
```

A scan before the first import finishes returns
`matcher is not initialized: initial load in progress` — wait and retry.

## How it differs from upstream's image

| | upstream `scanner-v4` | this image |
|---|---|---|
| Vulnerability data | fetched **through Central** (release build) | fetched directly from `definitions.stackrox.io` |
| Certificates | issued by Central | minted on first start by `stackrox-certs` |
| Who can call it | Central and Sensors | anyone holding the client cert in the volume |
| Config | Helm / operator | rendered from environment variables |

Upstream release builds route every matcher download through Central; this
image builds the same source without the `release` build tag. See
[docs/standalone-scanning.md](docs/standalone-scanning.md).

## Keeping current

Nothing to schedule. The matcher checks the bundle every ~5 minutes (plus
jitter) with `If-Modified-Since` and imports only the sources that changed;
upstream rebuilds the bundle hourly. The data lives in Postgres, so keep its
volume: a restart then resumes in seconds instead of re-importing.

## Configuration

| Variable | Default | |
|---|---|---|
| `SCANNER_DB_HOST` | `localhost` | Postgres host |
| `SCANNER_DB_PORT` | `5432` | |
| `SCANNER_DB_USER` | `postgres` | |
| `SCANNER_DB_NAME` | `postgres` | |
| `SCANNER_DB_SSLMODE` | `disable` | pod-local traffic |
| `SCANNER_DB_PASSWORD_FILE` | | preferred |
| `SCANNER_DB_PASSWORD` | | moved to a 0600 temp file at start |
| `SCANNER_VULN_URL` | upstream `v4` bundle | air-gapped: serve the zip yourself |
| `SCANNER_LOG_LEVEL` | `info` | |

Volume `/var/lib/stackrox` holds the CA, the certs and the rendered config.

## Running it as a service

`deploy/quadlet/` holds the Podman quadlets used on a workstation: a pod, the
Postgres and the scanner, loopback ports only, data under
`~/srv/stackrox/data/{postgres,stackrox}`, and the DB password delivered from a
secret store into an EnvironmentFile.

## Docs

| | |
|---|---|
| [docs/standalone-scanning.md](docs/standalone-scanning.md) | how the standalone mode works and why |
| [docs/rhhi-results.md](docs/rhhi-results.md) | Hummingbird scan results against this scanner |
| [CHANGELOG.md](CHANGELOG.md) | releases, numbered after upstream |

## License

Packaging: AGPL-3.0-or-later. StackRox itself: Apache-2.0.
