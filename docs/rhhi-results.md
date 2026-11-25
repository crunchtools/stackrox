# Hummingbird scan results

Red Hat Hardened Images (Hummingbird) identify as `ID=hummingbird` in
`os-release`, carry the CPE `cpe:/a:redhat:hummingbird:1`, and are covered in
Red Hat's CSAF VEX feed under products named `hummingbird-1:…`. claircore
detects the distribution and matches it through its `rhel-vex` updater; Scanner
V4 5.0.0 ships that support.

## Results, 2026-11-12, StackRox Scanner V4 5.0.0, bundle `v4`

| Image | Distribution | Vulnerabilities |
|---|---|---|
| `registry.access.redhat.com/hi/go` (latest) | `hummingbird` | 14 |
| `registry.access.redhat.com/hi/nginx` (latest) | `hummingbird` | 6 |
| `registry.access.redhat.com/hi/python` (latest) | `hummingbird` | 11 |
| `hi/go`, the older digest from claircore's test suite | `hummingbird` | 299 |

The older `hi/go` digest met all 8 of claircore's Hummingbird test expectations,
with matches from both `rhel-vex` (RPM content) and OSV (the Go standard
library).

## Notes

- Clair's 4.9.0 release predates Hummingbird support; Clair built from `main`
  detects it.
- `hi/python` scans cleanly here. Newer claircore (v1.6.2 and later) fails to
  index it because of the CycloneDX `bom.cdx.json` that pip 26 installs.
- Counts move as Red Hat's VEX data and the images change; rerun before quoting.
