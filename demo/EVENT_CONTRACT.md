# Demo event contract

Both live adapters emit one JSON object per process event and POST NDJSON to the same RSigma HTTP input. They preserve source-native fields and add only the common metadata needed for routing, correlation, and deterministic replay.

## Common fields

- `@timestamp`: RFC 3339 event time.
- `source_type`: `auditd` or `tetragon`; this selects the schema-routing binding.
- `Host`: stable host name used by correlation.
- `User`: decimal UID encoded as a string and used by correlation.

## auditd event

The audit coalescer joins records with the same audit message ID. The adapter exposes SigmaHQ auditd fields such as `type`, `a0`, `a1`, and `a2`, plus `audit_id`.

```json
{"@timestamp":"2026-10-04T10:00:00Z","source_type":"auditd","Host":"lss-demo","User":"1001","type":"EXECVE","a0":"whoami","audit_id":"1000.001:1"}
```

## Tetragon event

The adapter retains the nested Tetragon process event. It derives `demo.command_line` by joining the executable and argument fields because Sigma process-creation rules commonly refer to a complete command line.

```json
{"@timestamp":"2026-10-04T10:00:02Z","source_type":"tetragon","Host":"lss-demo","User":"1001","process_exec":{"process":{"binary":"/usr/bin/curl","uid":1001},"parent":{"binary":"/usr/bin/bash"}},"demo":{"command_line":"curl --silent http://127.0.0.1:18080/payload -o /tmp/lss-demo-payload"}}
```

The Tetragon processing pipeline maps portable Sigma fields onto the nested event:

- `Image` to `process_exec.process.binary`
- `CommandLine` to `demo.command_line`
- `ParentImage` to `process_exec.parent.binary`

The base SigmaHQ rules remain unchanged.
