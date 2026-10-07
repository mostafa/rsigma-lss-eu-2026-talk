# Supply-chain and hardening evidence

Captured on 4 October 2026 for `ghcr.io/timescale/rsigma:0.23.0`.

## Immutable image

Resolved multi-architecture digest:

```text
ghcr.io/timescale/rsigma@sha256:be3e4bcd9fd626fc15349455597c606cde08aa422724b4ea95bac1e5d504c40c
```

## Keyless signature

```bash
cosign verify \
  --certificate-identity-regexp 'github.com/timescale/rsigma' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/timescale/rsigma:0.23.0
```

Cosign verified two signatures, including certificate, transparency-log, and claim checks.

## Provenance and SBOM

`cosign tree` found a `https://slsa.dev/provenance/v1` OCI referrer. BuildKit SBOM inspection returned both release platforms:

```bash
docker buildx imagetools inspect \
  ghcr.io/timescale/rsigma:0.23.0 \
  --format '{{ json .SBOM }}'
```

```json
["linux/amd64", "linux/arm64"]
```

## Least-privilege validation

```bash
docker run --rm \
  --network=none \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --pids-limit=64 \
  -v "${PWD}/demo/rules:/rules:ro" \
  ghcr.io/timescale/rsigma:0.23.0 \
  rule validate /rules
```

The container parsed all five documents and compiled all four detection rules with no errors.
