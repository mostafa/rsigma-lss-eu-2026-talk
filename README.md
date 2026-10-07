# Detection Engineering with RSigma

Materials for the Linux Security Summit Europe 2026 talk, "Detection Engineering with RSigma."

[Talk page on the Linux Security Summit Europe 2026 website](https://lsseu2026.sched.com/event/2WHc4)

The talk follows one Linux detection from auditd and Tetragon telemetry through normalization, portable Sigma evaluation, stateful correlation, fixture-based testing, and deployment.

## Layout

- `deck/`: Marp slides, theme, and local assets.
- `demo/`: reproducible replay and live Multipass demonstration.
- `evidence/`: measured performance, footprint, hardening, and provenance results.
- `recordings/`: local fallback recording.

## Quick start

Prerequisites for the replay path are Bash, Python 3, curl, and Node.js. The live path also requires Multipass.

The deterministic replay is the baseline:

```bash
make replay
```

The replay emits four low-severity detections and one critical ordered correlation, rejects the benign fixture, and passes 10/10 backtest expectations.

Provision the Ubuntu 24.04 arm64 live environment:

```bash
make vm
```

Run the live demonstration:

```bash
make live
```

The prepared instance is named `rsigma-lss`. The verified restore point is `rsigma-lss.ready-v1`.

Run all local checks and render the deck:

```bash
make check
make render
```

Record the fallback video with VHS:

```bash
make record
```

## Verified results

- Four unmodified SigmaHQ rules detect a safe `whoami` → loopback `curl` → `chmod +x` → loopback `nc` sequence.
- One RSigma `temporal_ordered` correlation groups the signals by `Host` and `User` within 60 seconds.
- The coverage report maps all four expected ATT&CK techniques.
- Three live runs used about 21.5 MiB median RSS for the four-rule demonstration.
- The pinned RSigma container signature, SLSA provenance, SBOM, and hardened execution settings are recorded under `evidence/`.

## Reproducibility

External inputs are pinned in `versions.env`. The replay path does not require the VM. The live path does not require venue networking after provisioning.

## License

MIT
