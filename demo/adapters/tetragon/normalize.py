#!/usr/bin/env python3
"""Normalize Tetragon process events and optionally post them to RSigma."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import socket
import sys
import urllib.request
from collections.abc import Iterator
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--uid", type=int, default=1001)
    parser.add_argument("--host", default=socket.gethostname())
    parser.add_argument("--url")
    parser.add_argument("--capture")
    return parser.parse_args()


def normalize(
    event: dict[str, Any], expected_uid: int, hostname: str
) -> dict[str, Any] | None:
    process_exec = event.get("process_exec")
    if not isinstance(process_exec, dict):
        return None
    process = process_exec.get("process")
    if not isinstance(process, dict):
        return None

    try:
        uid = int(process.get("uid"))
    except (TypeError, ValueError):
        return None
    if uid != expected_uid:
        return None

    binary = str(process.get("binary", ""))
    arguments = str(process.get("arguments", "")).strip()
    command_line = " ".join(part for part in (binary, arguments) if part)
    timestamp = event.get("time") or process.get("start_time")
    if not isinstance(timestamp, str):
        timestamp = dt.datetime.now(dt.UTC).isoformat().replace("+00:00", "Z")

    normalized = dict(event)
    normalized.update(
        {
            "@timestamp": timestamp,
            "source_type": "tetragon",
            "Host": str(event.get("node_name") or hostname),
            "User": str(uid),
            "demo": {"command_line": command_line},
        }
    )
    return normalized


def read_events() -> Iterator[dict[str, Any]]:
    for line_number, line in enumerate(sys.stdin, start=1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as error:
            print(f"Tetragon adapter: line {line_number}: {error}", file=sys.stderr)
            continue
        if isinstance(event, dict):
            yield event


def emit(event: dict[str, Any], url: str | None, capture: str | None) -> None:
    payload = json.dumps(event, separators=(",", ":")).encode() + b"\n"
    if capture is not None:
        with open(capture, "ab") as output:
            output.write(payload)
    if url is None:
        sys.stdout.buffer.write(payload)
        sys.stdout.buffer.flush()
        return
    request = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/x-ndjson"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        if response.status >= 300:
            raise RuntimeError(f"RSigma returned HTTP {response.status}")


def main() -> None:
    args = parse_args()
    for event in read_events():
        normalized = normalize(event, args.uid, args.host)
        if normalized is not None:
            emit(normalized, args.url, args.capture)


if __name__ == "__main__":
    main()
