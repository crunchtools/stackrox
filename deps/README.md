# deps

`go.mod` and `go.sum` for the StackRox source the Containerfile builds: upstream
5.0.0's, with the modules grype flags moved to their fixed releases. The build
copies them over the extracted tarball and runs `go build -mod=readonly`, so it
resolves nothing itself.

To regenerate, for a new STACKROX_VERSION or another fix, in the build stage's
image (`quay.io/hummingbird/go:1.26-builder`), from the extracted tarball:

    go get golang.org/x/net@v0.60.0 github.com/go-jose/go-jose/v4@v4.1.6 \
      github.com/klauspost/compress@v1.20.2 \
      go.opentelemetry.io/otel/trace@v1.47.0 go.opentelemetry.io/otel/sdk@v1.47.0
    CGO_ENABLED=0 go build -mod=mod -o /dev/null ./scanner/cmd/scanner ./scanner/cmd/scannerctl
    cp go.mod go.sum <this directory>

The `-mod=mod` build is what records every go.sum line the build needs: `go get`
alone leaves some out (go.opentelemetry.io/otel/log), and `-mod=readonly` then
refuses to build.

and move the Containerfile's STACKROX_SHA256 with the version.
