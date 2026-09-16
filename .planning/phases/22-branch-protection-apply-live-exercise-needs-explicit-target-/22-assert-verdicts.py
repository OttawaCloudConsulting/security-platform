#!/usr/bin/env python3
"""22-assert-verdicts.py — the automated verification for Phase 22 plan 04.

Invoked as:  python3 <path-to-this-file> blocked
             python3 <path-to-this-file> clean

NEVER set this file's executable bit (project rule: scripts are invoked with an
explicit interpreter).

WHY IT EXISTS. Plan 04's deliverable is a *transition* in GitHub's merge verdict
on one constant tree hash, plus the literal text GitHub emits when it declines a
merge. Neither half is self-evidencing: a `BLOCKED` reading proves nothing
without the `UNSTABLE` control it moved away from, and a refusal transcript
proves nothing if the command was declined for a merge-method configuration
reason rather than by the gate. Every assertion below exists to close one of
those gaps, and each prints the values it compared so a failure is diagnosable
without re-running the live reads.

Exit 0 on success. Exit 1 with the failing assertion printed on failure.
Exit 2 on a usage error or a missing/unparseable evidence file — an
infrastructure problem, deliberately distinguished from a failed assertion.
"""

import json
import pathlib
import re
import sys

E = pathlib.Path(__file__).resolve().parent / "22-evidence"

FAILURES = []
CHECKS = 0


def fail(msg):
    FAILURES.append(msg)
    print(f"FAIL: {msg}")


def ok(msg):
    print(f"  ok: {msg}")


def check(cond, ok_msg, fail_msg):
    global CHECKS
    CHECKS += 1
    if cond:
        ok(ok_msg)
    else:
        fail(fail_msg)
    return cond


def load_json(name):
    p = E / name
    if not p.is_file():
        print(f"ABORT(2): missing evidence file: {p}")
        sys.exit(2)
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ABORT(2): {p} is not valid JSON: {exc}")
        sys.exit(2)


def load_text(name):
    p = E / name
    if not p.is_file():
        print(f"ABORT(2): missing evidence file: {p}")
        sys.exit(2)
    return p.read_text(encoding="utf-8")


# Text that would mean `gh pr merge` failed for a repository-configuration
# reason rather than being declined because the pull request is not mergeable.
# A configuration error reads like a refusal and is not one (T-22-19).
MERGE_METHOD_ERROR_PATTERNS = [
    r"(squash|rebase|merge commit)[a-z ]*(is|are)\s+not\s+allowed",
    r"merge\s+method[^.\n]*(disabled|not\s+allowed|unavailable|not\s+enabled)",
    r"not\s+enabled\s+(for|on)\s+this\s+repository",
    r"merging\s+is\s+not\s+allowed",
]


def assert_blocked():
    print("== verdict: blocked ==")

    blocked = load_json("merge-state-blocked.json")
    unstable = load_json("merge-state-unstable.json")

    # 1. Same head SHA on both readings. Without this the two verdicts are not
    #    comparable and the "only the ruleset write changed" claim is unfounded.
    b_sha = blocked.get("headRefOid")
    u_sha = unstable.get("headRefOid")
    check(
        b_sha is not None and b_sha == u_sha,
        f"blocked and unstable share headRefOid {b_sha}",
        f"headRefOid differs: blocked={b_sha!r} unstable={u_sha!r}",
    )

    # 2. The control must not itself be BLOCKED, or there is no discrimination
    #    to report — the transition IS the deliverable, not either value alone.
    u_state = unstable.get("mergeStateStatus")
    check(
        u_state != "BLOCKED",
        f"control verdict is {u_state!r}, not BLOCKED — the transition is real",
        f"control verdict is already BLOCKED; there is no transition to witness",
    )

    # 3. The deliverable reading itself.
    b_state = blocked.get("mergeStateStatus")
    check(
        b_state == "BLOCKED",
        f"blocked verdict reads {b_state!r}",
        f"blocked verdict reads {b_state!r}, expected 'BLOCKED'",
    )

    # 4. The refusal transcript exists, carries content, and was not obtained
    #    with the one flag that would have bypassed the gate being witnessed.
    attempt = load_text("merge-attempt.txt")
    check(
        attempt.strip() != "",
        f"merge-attempt.txt is non-empty ({len(attempt)} bytes)",
        "merge-attempt.txt is empty — no refusal was captured",
    )
    check(
        "--admin" not in attempt,
        "merge-attempt.txt contains no '--admin'",
        "merge-attempt.txt contains '--admin' — the gate was bypassed, not witnessed",
    )

    # 5. The refusal is a refusal, not a merge-method configuration error.
    hits = [p for p in MERGE_METHOD_ERROR_PATTERNS
            if re.search(p, attempt, re.IGNORECASE)]
    check(
        not hits,
        "merge-attempt.txt carries no merge-method configuration error",
        f"merge-attempt.txt matches merge-method error pattern(s): {hits}",
    )

    # 6. Nothing was merged — asserted from a fresh read of the PR, not from
    #    the merge command's own output.
    after = load_json("pr-after-attempt.json")
    check(
        after.get("state") == "OPEN",
        f"pull request is still {after.get('state')!r}",
        f"pull request state is {after.get('state')!r}, expected 'OPEN'",
    )
    check(
        after.get("mergedAt") is None,
        "mergedAt is null",
        f"mergedAt is {after.get('mergedAt')!r}, expected null",
    )

    # 7. The definitive proof that nothing landed: the target repository's
    #    default-branch HEAD is unchanged from the plan-01 capture.
    before_head = load_text("main-head-before.txt").strip()
    after_head = load_text("main-head-after-attempt.txt").strip()
    check(
        before_head == after_head and before_head != "",
        f"main HEAD unchanged at {before_head}",
        f"main HEAD MOVED: before={before_head!r} after={after_head!r}",
    )


def assert_clean():
    print("== verdict: clean ==")

    # 1. One tree, three commits. This invariant is what makes three merge
    #    verdicts comparable at all.
    hashes = {}
    for name in ("tree-hash-baseline.txt", "tree-hash-blocking.txt",
                 "tree-hash-clean.txt"):
        hashes[name] = load_text(name)
    distinct = set(hashes.values())
    check(
        len(distinct) == 1,
        f"three tree-hash files byte-identical: {hashes['tree-hash-clean.txt'].strip()}",
        f"tree hashes differ: { {k: v.strip() for k, v in hashes.items()} }",
    )

    # 2. Five green check runs at the third-verdict head SHA.
    runs = load_json("check-runs-clean.json")
    check(
        isinstance(runs, list) and len(runs) == 5,
        f"check-runs-clean.json holds {len(runs) if isinstance(runs, list) else '?'} entries",
        f"check-runs-clean.json holds {len(runs) if isinstance(runs, list) else runs!r} entries, expected 5",
    )
    if isinstance(runs, list):
        bad = [r for r in runs if r.get("conclusion") != "success"]
        check(
            not bad,
            "every check-run conclusion is 'success'",
            f"non-success conclusions: {[(r.get('name'), r.get('conclusion')) for r in bad]}",
        )

    # 3. The requirement did not go away — only the redness did. A green
    #    verdict with the requirement silently removed would prove nothing.
    ctx = load_json("required-contexts-still-set.json")
    check(
        isinstance(ctx, list) and len(ctx) == 5,
        f"required-contexts-still-set.json holds {len(ctx) if isinstance(ctx, list) else '?'} contexts",
        f"required-contexts-still-set.json holds {len(ctx) if isinstance(ctx, list) else ctx!r} contexts, expected 5",
    )
    if isinstance(ctx, list):
        wrong = [c for c in ctx if c.get("integration_id") != 15368]
        check(
            not wrong,
            "all five contexts pinned to integration_id 15368",
            f"contexts not pinned to 15368: {wrong}",
        )

    # 4. The phase-wide evidence gate: an artifact containing an unsettled
    #    merge state is not evidence (RESEARCH Pitfall 9).
    offenders = []
    for p in sorted(E.rglob("*")):
        if not p.is_file():
            continue
        try:
            if "UNKNOWN" in p.read_text(encoding="utf-8"):
                offenders.append(p.name)
        except (UnicodeDecodeError, OSError):
            continue
    check(
        not offenders,
        f"no file under 22-evidence/ contains 'UNKNOWN' ({sum(1 for p in E.rglob('*') if p.is_file())} files scanned)",
        f"files containing 'UNKNOWN': {offenders}",
    )


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("blocked", "clean"):
        print("ABORT(2): usage: python3 22-assert-verdicts.py <blocked|clean>")
        sys.exit(2)

    if sys.argv[1] == "blocked":
        assert_blocked()
    else:
        assert_clean()

    print()
    if FAILURES:
        print(f"RESULT: FAILED — {len(FAILURES)} of {CHECKS} assertions failed")
        sys.exit(1)
    print(f"RESULT: PASSED — {CHECKS}/{CHECKS} assertions")
    sys.exit(0)


if __name__ == "__main__":
    main()
