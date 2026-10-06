#!/usr/bin/env python3
"""Build the synthetic attempt directories for 29.6-verdict.sh (plan 29.6-03).

Each fixture is a full attempt directory per the 29.6-03 contract (meta.json,
timeline.jsonl, merge-stdout.txt, merge-stderr.txt, checkruns-final.json,
runs.json, pr-after.json, pr-timeline.json). Ids are synthetic but internally
consistent: three suites on one head SHA (opened < close < reopen), check-run
ids increasing within and across suites, DefectDojo jobs present as noise so
context scoping is exercised. Each fixture is built so exactly one verdict
rule fires.

Re-run (no executable bit): python3 build-fixtures.py   (writes next to itself)
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))

REPO = "OttawaCloudConsulting/race-fixture"
SHA = "f1x7e5" + "0" * 34
CTX = [
    "security / Secrets — Gitleaks",
    "security / SCA — Trivy Filesystem",
    "security / IaC — Checkov",
    "security / SAST — Semgrep CE",
    "security / Container — Trivy Image",
]
NOISE = ["security / DefectDojo Cleanup", "security / DefectDojo Import"]
RED = {"security / SAST — Semgrep CE", "security / SCA — Trivy Filesystem"}

OPEN_SUITE, CLOSE_SUITE, REOPEN_SUITE = 91000000001, 91000000002, 91000000003
OPEN_RUN, CLOSE_RUN, REOPEN_RUN = 51000000001, 51000000002, 51000000003
CR_BASE = {OPEN_SUITE: 71000000000, CLOSE_SUITE: 72000000000, REOPEN_SUITE: 73000000000}
RUN_OF = {OPEN_SUITE: OPEN_RUN, CLOSE_SUITE: CLOSE_RUN, REOPEN_SUITE: REOPEN_RUN}

ADR019_STDERR = (
    "X Pull request OttawaCloudConsulting/terraform-pipelines#14 is not mergeable: "
    "the base branch policy prohibits the merge.\n"
    "To have the pull request merged after all the requirements have been met, add the `--auto` flag.\n"
    "To use administrator privileges to immediately merge the pull request, add the `--admin` flag.\n"
)
FLAG_HINTS_ONLY = "".join(ADR019_STDERR.splitlines(True)[1:])
SERVER_STDERR = (
    "GraphQL: Repository rule violations found\n\n"
    "2 of 5 required status checks have not succeeded. (mergePullRequest)\n"
)


def cr(name, suite, idx, status, conclusion, t):
    return {
        "name": name,
        "id": CR_BASE[suite] + idx,
        "status": status,
        "conclusion": conclusion if status == "completed" else None,
        "suite": suite,
        "run": RUN_OF[suite],
        "started_at": t if status != "queued" else None,
        "completed_at": t if status == "completed" else None,
    }


def suite_runs(suite, t, green=False, statuses=None, only=None):
    """All five contexts plus noise for one suite; statuses overrides per name."""
    out = []
    for i, name in enumerate(CTX + NOISE):
        if only is not None and name not in only:
            continue
        status = (statuses or {}).get(name, "completed")
        if suite == CLOSE_SUITE or name in NOISE:
            concl = "skipped"
        elif green or name not in RED:
            concl = "success"
        else:
            concl = "failure"
        out.append(cr(name, suite, i, status, concl, t))
    return out


def newest(check_runs):
    res = []
    for n in CTX:
        c = [x for x in check_runs if x["name"] == n]
        res.append(max(c, key=lambda x: x["id"]) if c else {"name": n, "missing": True})
    return res


def snapline(label, ts, state, mss, check_runs):
    crs = sorted(check_runs, key=lambda x: x["id"])
    return {
        "label": label,
        "ts": ts,
        "pr": {"state": state, "mergeStateStatus": mss, "mergeable": "MERGEABLE", "headRefOid": SHA},
        "check_runs": crs,
        "newest": newest(crs),
    }


def runs_json(t_close_created, final_status="completed"):
    return [
        {"id": OPEN_RUN, "created_at": "2026-10-06T12:00:00Z", "status": "completed",
         "conclusion": "failure", "check_suite_id": OPEN_SUITE, "event": "pull_request", "run_attempt": 1},
        {"id": CLOSE_RUN, "created_at": t_close_created, "status": "completed",
         "conclusion": "skipped", "check_suite_id": CLOSE_SUITE, "event": "pull_request", "run_attempt": 1},
        {"id": REOPEN_RUN, "created_at": "2026-10-06T12:05:03Z", "status": final_status,
         "conclusion": "failure", "check_suite_id": REOPEN_SUITE, "event": "pull_request", "run_attempt": 1},
    ]


def write(name, meta, timeline, final, runs, after, stdout, stderr, pr_timeline):
    d = os.path.join(HERE, name)
    os.makedirs(d, exist_ok=True)

    def dump(fn, obj):
        with open(os.path.join(d, fn), "w", encoding="utf-8") as f:
            json.dump(obj, f, indent=2, ensure_ascii=False)
            f.write("\n")

    dump("meta.json", meta)
    with open(os.path.join(d, "timeline.jsonl"), "w", encoding="utf-8") as f:
        for line in timeline:
            f.write(json.dumps(line, ensure_ascii=False, separators=(",", ":")) + "\n")
    dump("checkruns-final.json", sorted(final, key=lambda x: x["id"]))
    dump("runs.json", runs)
    dump("pr-after.json", after)
    dump("pr-timeline.json", pr_timeline)
    with open(os.path.join(d, "merge-stdout.txt"), "w", encoding="utf-8") as f:
        f.write(stdout)
    with open(os.path.join(d, "merge-stderr.txt"), "w", encoding="utf-8") as f:
        f.write(stderr)


def base_meta(label, variant, merge_rc, t_close, gate="blocking"):
    m = {
        "label": label,
        "variant": variant,
        "repo": REPO,
        "pr": 7,
        "head_sha": SHA,
        "contexts": CTX,
        "gate_mode": gate,
        "current_user_can_bypass": "never",
        "bypass_actors": [],
        "t_close": t_close,
        "t_reopen_start": "2026-10-06T12:05:01.100Z",
        "t_reopen_end": "2026-10-06T12:05:01.900Z",
        "t_premerge_read": "2026-10-06T12:05:02.000Z",
        "premerge_state": {"mergeStateStatus": "UNKNOWN", "mergeable": "UNKNOWN", "headRefOid": SHA},
        "t_merge_start": "2026-10-06T12:05:02.100Z",
        "t_merge_end": "2026-10-06T12:05:03.400Z",
        "close_rc": 0,
        "reopen_rc": 0,
        "merge_rc": merge_rc,
    }
    if variant == "a":
        m["t_detect"] = "2026-10-06T12:05:00.500Z"
    return m


def pr_events(merged):
    ev = [{"event": "closed", "created_at": "2026-10-06T12:04:00Z"},
          {"event": "reopened", "created_at": "2026-10-06T12:05:01Z"}]
    if merged:
        ev.append({"event": "merged", "created_at": "2026-10-06T12:05:03Z"})
    return ev


def build(name, variant, merge_rc, after_state, stderr, stdout="", green=False,
          t_close="2026-10-06T12:04:00.000Z", close_created="2026-10-06T12:04:01Z",
          post_merge=None):
    opened = suite_runs(OPEN_SUITE, "2026-10-06T12:01:00Z", green=green)
    close = suite_runs(CLOSE_SUITE, "2026-10-06T12:04:30Z")
    reopen = suite_runs(REOPEN_SUITE, "2026-10-06T12:07:00Z", green=green)
    mss = "CLEAN" if green else "BLOCKED"
    tl = [snapline("pre-close", "2026-10-06T12:03:59.000Z", "OPEN", mss, opened)]
    if variant == "a":
        tl.append(snapline("pre-reopen", "2026-10-06T12:05:00.900Z", "CLOSED", mss, opened + close))
    if post_merge is None:
        # default: close suite done, reopen suite queued on every name
        post_merge = opened + close + suite_runs(
            REOPEN_SUITE, None, statuses={n: "queued" for n in CTX + NOISE})
    post_state = "MERGED" if after_state == "MERGED" else "OPEN"
    tl.append(snapline("post-merge", "2026-10-06T12:05:04.000Z", post_state, "UNKNOWN", post_merge))
    tl.append(snapline("settle-1", "2026-10-06T12:05:07.000Z", post_state, "UNKNOWN", opened + close + reopen))
    tl.append(snapline("final", "2026-10-06T12:07:30.000Z", post_state,
                       "UNKNOWN" if post_state == "MERGED" else mss, opened + close + reopen))
    merged = after_state == "MERGED"
    after = {"state": after_state,
             "mergedAt": "2026-10-06T12:05:03Z" if merged else None,
             "mergeCommit": {"oid": "a" * 40} if merged else None,
             "headRefOid": SHA}
    write(name, base_meta("fixture-" + name, variant, merge_rc, t_close), tl,
          opened + close + reopen, runs_json(close_created), after, stdout, stderr, pr_events(merged))


MERGED_STDOUT = "✓ Squashed and merged pull request OttawaCloudConsulting/race-fixture#7\n"

# blocked, client-side refusal (ADR-019 verbatim), variant b
build("blocked-client", "b", 1, "OPEN", ADR019_STDERR)

# blocked, server-side refusal, variant a (pre-reopen snap shows the close suite complete)
build("blocked-server", "a", 1, "OPEN", SERVER_STDERR)

# lost, variant b: at post-merge two contexts' newest are close-suite skipped,
# one is a queued reopen run, two are still the opened suite's runs.
# t_close is deliberately LATER than the close run's created_at (clock skew).
lost_post = (
    suite_runs(OPEN_SUITE, "2026-10-06T12:01:00Z")
    + suite_runs(CLOSE_SUITE, "2026-10-06T12:04:30Z",
                 only={"security / Secrets — Gitleaks", "security / SCA — Trivy Filesystem",
                       "security / IaC — Checkov"})
    + suite_runs(REOPEN_SUITE, None, statuses={"security / IaC — Checkov": "queued"},
                 only={"security / IaC — Checkov"})
)
build("lost", "b", 0, "MERGED", "", stdout=MERGED_STDOUT,
      t_close="2026-10-06T12:04:09.123Z", close_created="2026-10-06T12:04:05Z",
      post_merge=lost_post)

# invalid: green prior state (CLEAN, all success), merge accepted
build("invalid-green", "b", 0, "MERGED", "", stdout=MERGED_STDOUT, green=True)

# anomaly: merge rc 0 but the PR is still OPEN
build("anomaly", "b", 0, "OPEN", "", stdout=MERGED_STDOUT)

# blocked with an unrecognised refusal
build("unclassified", "b", 1, "OPEN", "something else\n")

# classifier-only input: the two CLI flag-hint lines with no policy line
with open(os.path.join(HERE, "flag-hint-only-stderr.txt"), "w", encoding="utf-8") as f:
    f.write(FLAG_HINTS_ONLY)
