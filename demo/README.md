# Demo

The deterministic and live paths exercise the same four SigmaHQ detection rules and one ordered correlation.

## Deterministic replay

```bash
./demo/run.sh --replay
```

The first run downloads the pinned RSigma release for the current arm64 operating system and verifies its SHA-256 digest. Replay then:

1. Evaluates the malicious fixture with schema routing.
2. Requires the exact sequence of four low-severity detections and one critical correlation.
3. Requires zero matches for the benign fixture.
4. Runs ten backtest expectations with unexpected detections configured to fail.

## Live Multipass path

Provision once while network access is available:

```bash
./demo/vm/launch.sh
```

This launches Ubuntu 24.04 arm64, checks BTF/cgroup v2/audit support, and installs the pinned RSigma, Tetragon, and Laurel releases.

Run the demonstration:

```bash
./demo/run.sh --live
```

RSigma runs inside the VM. Laurel coalesces audit records, Tetragon supplies eBPF process events, and two adapters post normalized NDJSON to one local HTTP input. The attack sequence uses a dedicated non-root user and loopback only.

## Event contract

See `EVENT_CONTRACT.md`. Processing pipelines rewrite rule fields, not event payloads. The adapters preserve source-native structures and add routing/correlation metadata.

## Rules

The four base rules are unmodified copies from the SigmaHQ commit in `versions.env`. See `rules/PROVENANCE.md`. The demonstration-specific correlation orders them by one `Host` and `User` within 60 seconds.

## Offline stage operation

Provision and snapshot the VM before travel. Neither `--live` nor `--replay` needs external network access after dependencies are installed. If the VM is unhealthy, switch to replay without changing the rules or expected result.
