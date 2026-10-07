#!/usr/bin/env python3
"""Normalize Laurel audit events and optionally post them to RSigma."""

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


def event_timestamp(event: dict[str, Any]) -> str:
    event_id = str(event.get("ID", ""))
    try:
        epoch = float(event_id.split(":", maxsplit=1)[0])
    except ValueError:
        return dt.datetime.now(dt.UTC).isoformat().replace("+00:00", "Z")
    return dt.datetime.fromtimestamp(epoch, dt.UTC).isoformat().replace("+00:00", "Z")


def argument_vector(event: dict[str, Any]) -> list[str]:
    execve = event.get("EXECVE")
    if not isinstance(execve, dict):
        return []
    argv = execve.get("ARGV")
    if isinstance(argv, list):
        return [str(value) for value in argv]
    argv_string = execve.get("ARGV_STR")
    if isinstance(argv_string, str):
        return argv_string.split()
    return []


def normalize(
    event: dict[str, Any], expected_uid: int, hostname: str
) -> dict[str, Any] | None:
    syscall = event.get("SYSCALL")
    if not isinstance(syscall, dict):
        return None
    uid = syscall.get("uid", syscall.get("auid"))
    try:
        numeric_uid = int(uid)
    except (TypeError, ValueError):
        return None
    if numeric_uid != expected_uid:
        return None

    argv = argument_vector(event)
    if not argv:
        return None

    normalized: dict[str, Any] = {
        "@timestamp": event_timestamp(event),
        "source_type": "auditd",
        "Host": str(event.get("NODE") or hostname),
        "User": str(numeric_uid),
        "type": "EXECVE",
        "audit_id": str(event.get("ID", "")),
        "auditd": event,
    }
    for index, value in enumerate(argv[:16]):
        normalized[f"a{index}"] = value
    return normalized


def read_events() -> Iterator[dict[str, Any]]:
    for line_number, line in enumerate(sys.stdin, start=1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as error:
            print(f"audit adapter: line {line_number}: {error}", file=sys.stderr)
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
