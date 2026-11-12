# Standalone Scanner V4

StackRox Scanner V4 is built to live inside a StackRox deployment. Running it
alone takes three changes, all made in packaging, none in upstream code.

## 1. Build without the `release` tag

In a release build the matcher's HTTP client denies every destination except
Central (`scanner/matcher/matcher.go`, `scanner/internal/httputil`), because in
a cluster Central proxies the vulnerability bundle. Alone, there is no Central,
and the matcher logs `HTTP traffic denied` forever.

Built without the tag, the matcher fetches the bundle itself. The other
differences between the flavours are minimum garbage-collection intervals and
whether feature flags may be changed at runtime.

A non-release build would default to the `dev` bundle, so the entrypoint pins
the URL to the stream this release reads:

```
https://definitions.stackrox.io/v4/vulnerability-bundles/v4/vulnerabilities.zip
```

`v4` comes from `scanner/VULNERABILITY_VERSION` in the 5.0.0 tree; the build
fails if the two disagree.

## 2. Mint the identities it checks

Scanner V4 speaks gRPC over mutual TLS and authorizes by certificate subject:
OU is the service type, CN is `<TYPE>: <name>` (`pkg/mtls/cn.go`). The indexer
and matcher APIs accept Central and Sensors only (`scanner/services`).
`stackrox-certs` therefore makes:

| File | Subject | Used by |
|---|---|---|
| `certs/ca.pem`, `ca-key.pem` | private CA | signing, once |
| `certs/scanner/*` | `SCANNER_V4_SERVICE: Scanner V4`, SAN `scanner-v4.stackrox`, `localhost` | the server |
| `certs/client/*` | `CENTRAL_SERVICE: Central` | `stackrox-scan` |

Anyone holding `certs/client/` can submit scans, which is why the ports are
published to loopback only.

## 3. Render the config from the environment

`stackrox-entrypoint` writes `/var/lib/stackrox/config.yaml` on every start:
indexer and matcher enabled in one process, both on the same Postgres, gRPC on
8443, HTTP (health) on 9443. The password is passed by file path.

## Data flow

```
definitions.stackrox.io ──(every ~5 min, If-Modified-Since)──▶ matcher ──▶ Postgres
security.access.redhat.com (repo→CPE maps) ──────────────────▶ indexer ──▶ Postgres
registry ──(image layers)──▶ indexer ── index report ──▶ matcher ──▶ vulnerability report
```

Upstream rebuilds the bundle hourly from its source updaters (Red Hat CSAF VEX,
NVD, OSV, distribution feeds). The matcher re-imports only the sources whose
timestamps moved; the full ~15-minute load happens once, on the first start
against an empty database.
