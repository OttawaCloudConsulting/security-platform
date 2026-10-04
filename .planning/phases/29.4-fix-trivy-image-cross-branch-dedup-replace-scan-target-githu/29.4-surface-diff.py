#!/usr/bin/env python3
"""29.4-surface-diff.py - D-14.3 structural surface check for security.yml.

Usage:
  python3 29.4-surface-diff.py <ref-a-yaml> <ref-b-yaml> --expect <job>=<step> [--expect ...]

Loads both workflow files with PyYAML, recursively drops every `run` key and
compares the remaining structure (on.workflow_call inputs and secrets, job ids
and names, SARIF categories, artifact names, uses: pins, if: guards, with: and
env: blocks). Then compares the `run` bodies keyed by (job id, step id or step
name) and prints the set of changed bodies.

Exit 0 only if the non-run structure is identical AND the set of changed run
bodies equals the --expect set exactly. Exit 1 otherwise. Exit 2 on usage or
parse errors. Run with an explicit interpreter; this file has no executable bit.
"""
import argparse
import sys

import yaml


def strip(o):
    if isinstance(o, dict):
        return {k: strip(v) for k, v in o.items() if k != "run"}
    if isinstance(o, list):
        return [strip(x) for x in o]
    return o


def diff_paths(a, b, path="$"):
    """Yield human-readable paths where a and b differ."""
    if type(a) is not type(b):
        yield f"{path}: type {type(a).__name__} != {type(b).__name__} ({a!r} vs {b!r})"
        return
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b), key=str):
            p = f"{path}.{k}"
            if k not in a:
                yield f"{p}: only in B"
            elif k not in b:
                yield f"{p}: only in A"
            else:
                yield from diff_paths(a[k], b[k], p)
    elif isinstance(a, list):
        if len(a) != len(b):
            yield f"{path}: list length {len(a)} != {len(b)}"
        for i, (x, y) in enumerate(zip(a, b)):
            yield from diff_paths(x, y, f"{path}[{i}]")
    elif a != b:
        yield f"{path}: {a!r} != {b!r}"


def run_bodies(doc):
    """Map (job id, step key) -> run body. Job-level run keys use step key '<job>'."""
    out = {}
    jobs = doc.get("jobs") or {}
    for job_id, job in jobs.items():
        if not isinstance(job, dict):
            continue
        for idx, step in enumerate(job.get("steps") or []):
            if not isinstance(step, dict) or "run" not in step:
                continue
            key = step.get("id") or step.get("name") or f"#{idx}"
            pair = (str(job_id), str(key))
            if pair in out:
                raise SystemExit(f"ERROR: duplicate step key {pair}")
            out[pair] = step["run"]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--expect", action="append", default=[], metavar="JOB=STEP")
    args = ap.parse_args()

    expect = set()
    for e in args.expect:
        if "=" not in e:
            print(f"ERROR: --expect needs JOB=STEP, got {e!r}", file=sys.stderr)
            return 2
        j, s = e.split("=", 1)
        expect.add((j, s))

    try:
        with open(args.a, encoding="utf-8") as f:
            a = yaml.safe_load(f)
        with open(args.b, encoding="utf-8") as f:
            b = yaml.safe_load(f)
    except (OSError, yaml.YAMLError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    ok = True
    sa, sb = strip(a), strip(b)
    if sa == sb:
        print("STRUCTURE: IDENTICAL (all keys except run)")
    else:
        ok = False
        print("STRUCTURE: DIFFERENT")
        for line in diff_paths(sa, sb):
            print(f"  {line}")

    ra, rb = run_bodies(a), run_bodies(b)
    changed = set()
    for pair in sorted(set(ra) | set(rb)):
        if ra.get(pair) != rb.get(pair):
            changed.add(pair)
    print(f"CHANGED RUN BODIES ({len(changed)}):")
    for j, s in sorted(changed):
        print(f"  {j} = {s}")

    unexpected = changed - expect
    missing = expect - changed
    if unexpected:
        ok = False
        print("UNEXPECTED CHANGED RUN BODIES:")
        for j, s in sorted(unexpected):
            print(f"  {j} = {s}")
    if missing:
        ok = False
        print("EXPECTED BUT UNCHANGED RUN BODIES:")
        for j, s in sorted(missing):
            print(f"  {j} = {s}")

    print(f"SURFACE-DIFF: {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
