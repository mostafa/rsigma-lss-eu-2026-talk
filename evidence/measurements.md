# Measurement record

Every number used in the talk must identify its workload, hardware, build, and capture date.

## Published RSigma benchmark context

Sources: `timescale/rsigma` `BENCHMARKS.md` and the v0.21.0 entries in `CHANGELOG.md`. The primary benchmark host is an Apple M4 Pro running macOS.

### Format and state workloads

- Syslog: 10,000 events through the complete runtime pipeline with 100 synthetic rules, 1.57 million events/sec.
- JSON: 10,000 events through the complete runtime pipeline with 100 synthetic rules, 1.12 million events/sec.
- CEF: 10,000 events through the complete runtime pipeline with 100 synthetic rules, 527,000 events/sec.
- OTLP: 10,000 records flattened into engine events, 439,000 records/sec. This excludes transport and detection.
- Temporal correlation: 1,000 events against 3-10 temporal rules, 1.76 million events/sec.
- Distinct `value_count`: 100 groups at one event/sec with 1,800 distinct values retained per window, 57,000 events/sec.

### Representative SigmaHQ corpus

Corpus: 3,132 SigmaHQ detection rules at commit `994da166`. Each lane uses 100,000 deterministic events. Offline figures are single-core and net of rule load. HTTP daemon figures use batch size 512 and four concurrent NDJSON posters. The harness reports the median of three measured runs.

- Structured Windows: 19,358 events/sec offline and 87,704 events/sec through the daemon.
- Raw Windows blobs with logsource routing: 98,836 events/sec offline and 342,070 events/sec through the daemon.
- Cisco AAA syslog with logsource routing: 106,241 events/sec offline and 401,364 events/sec through the daemon.
- Sysmon file events with logsource routing: 45,481 events/sec offline and 174,550 events/sec through the daemon.
- Peak RSS for corpus load plus evaluation: approximately 113 MB.
- The production candidate index returns a p95 of 0.29-3.86 percent of the 3,132 rules, depending on lane.

Later v0.21.0 sustained-path tuning measured approximately 708,000 events/sec on the routed raw-Windows lane with batch size 512, eight rayon threads, 16 k6 virtual users, and five detection batches in flight. This is a correlation-free path. Engines with correlation preserve ordering and process one batch at a time.

### Correlation memory pressure

- One million unique session keys under the default 100,000-entry cap: 39.8 MiB peak heap, 22.4 MiB settled, and 841,000 events/sec while stale groups are evicted.
- One million unique session keys with the cap raised to two million: 327.4 MiB peak heap, 243.8 MiB settled, and 742,000 events/sec with all one million groups live.
- A live session group costs approximately 256 bytes settled. `event_count` retains approximately 10 bytes per in-window event, while distinct-string `value_count` retains approximately 92 bytes per in-window event.

The synthetic, representative, tuned-daemon, and state-pressure figures are not interchangeable. Every number in the talk labels the rule corpus, input shape, concurrency, and retained state that produced it.

## Demo measurement

Captured on 4 October 2026 using the pinned RSigma v0.23.0 Linux arm64 release inside the Ubuntu 24.04.5 arm64 Multipass VM. RSigma loaded four detection rules, one temporal correlation, two schema-routing engines, and a file sink. The measurement was taken after the correlation fired. Tetragon, auditd, Laurel, and the VM are excluded.

Capture command:

```bash
pid="$(pidof rsigma)"
awk '/VmRSS|VmPeak/ {print}' "/proc/${pid}/status"
```

Three consecutive clean runs produced exactly four low-severity detections and one critical correlation. RSS after correlation was 21,996 kB, 21,768 kB, and 22,004 kB. Median result:

```text
VmPeak: 721588 kB
VmRSS:   21996 kB
```

The current live daemon therefore uses approximately 21.5 MiB resident memory for this workload. The talk must not repeat the older sub-15 MB claim as a current unconditional result.
