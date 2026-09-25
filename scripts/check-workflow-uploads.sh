#!/usr/bin/env bash
set -euo pipefail

# check-workflow-uploads.sh — offline static gate for the SARIF-upload and
# artifact-retention invariants that Phase 17 rests on.
#
# WHY THIS EXISTS. ADR-001 makes `continue-on-error: true` mandatory on every
# scan and upload step, so a SARIF upload that 403s (missing
# `security-events: write`) or an artifact upload that silently drops leaves
# NO red step in the run. The pipeline ships broken-but-green. This script is
# the offline half of the evidence: a single command that decides PASS/FAIL
# for every invariant that can be decided from the workflow source alone,
# without a CI run and without network access.
#
# It parses EVERY workflow file (*.yml and *.yaml under .github/workflows)
# with PyYAML and reports EVERY failure rather than stopping at the first, so
# one run tells you the whole story. The caller/callee-specific checks still
# read pr-security.yml, security.yml and (CALLER-WIRING) scheduled-security.yml
# by name; PERMISSIONS-FORBIDDEN, SHA-PIN
# and the step-level checks walk every file (Phase 27 D-22), so a new workflow
# file cannot slip in an unpinned action.
#
# SCAN JOBS vs SIDE-CHANNEL JOBS (Phase 27, ADR-024). security.yml carries the
# five frozen scan jobs (SCAN_JOB_IDS) and MUST carry the two allow-listed
# DefectDojo side-channel jobs (SIDE_CHANNEL_JOB_IDS); any other job id fails
# JOB-SHAPE. No Phase 27 check passes vacuously: an absent side-channel job or
# an absent scheduled-security.yml is a named failure. Which check guards which
# Phase 27 decision:
#   D-01  JOB-SHAPE                  scan jobs keep ids, names, no needs:
#   D-03  SIDE-CHANNEL-NOT-REQUIRED  a DefectDojo job is never a required check
#         SIDE-CHANNEL-SHAPE         needs/if/env/shell contract of both jobs
#         IMPORT-VERIFY-PAIRING      a continue-on-error step is read back red
#   D-12  OPTIONAL-SECRET            DEFECTDOJO_API_TOKEN declared required: false
#         CALLER-WIRING              both callers pass exactly that one secret,
#                                    never `secrets: inherit`, and no with:
#         NO-INTERPOLATION           no ${{ }} inside a DefectDojo run: body
#   D-15  SCAN-JOB-CLOSED-SKIP       all five scan jobs skip on PR `closed`
#         CALLER-WIRING              pr-security.yml types are exactly
#                                    [opened, synchronize, reopened, closed];
#                                    scheduled-security.yml runs daily at
#                                    06:00 America/Toronto plus workflow_dispatch
#   D-18  INSECURE-WARNING           the insecure-TLS path prints ::warning::
#         SCHEME                     DEFECTDOJO_URL must be https:// (refused before
#                                    the token header is written) and every curl is
#                                    pinned with --proto/--proto-redir =https (CR-01)
#
# Self-test overrides (optional, used only to point the gate at scratch copies):
#   WORKFLOWS_DIR           default .github/workflows
#   REQUIRED_CHECKS_SCRIPT  default scripts/set-required-checks.sh
#
# Exit codes — deliberately three, not two:
#   0  every check passed
#   1  at least one assertion failed  (a workflow defect — fix the YAML)
#   2  preflight failed: pyyaml is not importable (an INFRASTRUCTURE problem
#      on this machine, not a workflow defect). The two must never be
#      conflated, and there is deliberately NO regex fallback: a silent
#      fallback that "mostly works" is exactly the failure mode this gate
#      exists to prevent.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/check-workflow-uploads.sh
#
# SCOPE NOTE FOR FUTURE READERS: this gate deliberately asserts NO counts of
# upload steps. It must pass at every intermediate commit of Phase 17, so the
# exact number of SARIF and artifact upload steps is asserted inline by plans
# 17-03 and 17-04, not here. Do not "complete" this script by adding a count.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Preflight. Distinct exit code 2 — see the header.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "PREFLIGHT FAIL: python3 yaml module (pyyaml) not available — install with: python3 -m pip install pyyaml"
  exit 2
fi

echo "check-workflow-uploads: parsing every workflow file in ${WORKFLOWS_DIR:-.github/workflows} (*.yml, *.yaml)"

# The heredoc delimiter is QUOTED ('PY') on purpose: the python source below
# contains $, * and GitHub ${{ }} expression fragments that an unquoted
# delimiter would let the shell expand before python ever saw them.
rc=0
python3 - <<'PY' || rc=$?
import glob
import os
import re
import sys

import yaml

WORKFLOWS_DIR = os.environ.get("WORKFLOWS_DIR") or ".github/workflows"
REQUIRED_CHECKS_SCRIPT = os.environ.get("REQUIRED_CHECKS_SCRIPT") or "scripts/set-required-checks.sh"

CALLER = os.path.join(WORKFLOWS_DIR, "pr-security.yml")
CALLEE = os.path.join(WORKFLOWS_DIR, "security.yml")
SCHEDULED = os.path.join(WORKFLOWS_DIR, "scheduled-security.yml")

# The five check-run names Phase 14-02 captured and Phase 18 hard-codes into
# the branch-protection required-check list. Byte-identical, em dash U+2014.
# Renaming any of them would point branch protection at a check that no longer
# exists — silently non-blocking.
FROZEN_JOB_NAMES = [
    "SAST — Semgrep CE",
    "IaC — Checkov",
    "SCA — Trivy Filesystem",
    "Container — Trivy Image",
    "Secrets — Gitleaks",
]

# The five scan-job ids, in the SAME order as FROZEN_JOB_NAMES: the name of
# jobs[SCAN_JOB_IDS[i]] must equal FROZEN_JOB_NAMES[i].
SCAN_JOB_IDS = ["sast", "iac", "sca", "container", "secrets"]

# The only jobs allowed beside the scan jobs (Phase 27 D-01/D-03). They are a
# tolerated side channel into DefectDojo: never required checks, never able to
# block a merge. Any other job id fails JOB-SHAPE.
SIDE_CHANNEL_JOB_IDS = ["defectdojo-import", "defectdojo-cleanup"]
SIDE_CHANNEL_JOB_NAMES = ["DefectDojo Import", "DefectDojo Cleanup"]

# Scopes that must never appear anywhere in either file (ASVS V4, T-17-01).
FORBIDDEN_SCOPES = (
    ("contents", "write"),
    ("pull-requests", "write"),
    ("actions", "write"),
    ("id-token", "write"),
)

BLANKET_VALUES = ("write-all", "read-all")

SHA_RE = re.compile(r"^[0-9a-f]{40}$")

# Anchored, extension-restricted artifact path: a bare basename ending .json
# or .sarif. No directory component, no leading /, no bare `.`. A public
# repository's artifacts are world-downloadable, so a loose glob is a finding,
# not a style issue (ASVS V12, T-17-05).
ARTIFACT_PATH_RE = re.compile(r"^[A-Za-z0-9_.*-]+\.(json|sarif)$")

# A gitleaks INVOCATION, not the substring "gitleaks". The install step's run
# block mentions gitleaks.tar.gz, the release URL and `sudo tar ... gitleaks`
# — none of which redact anything and none of which should be flagged. Only a
# line whose first word is `gitleaks` is a scanner run. Do not simplify this
# to `"gitleaks" in run`: it produces a false failure on the install step.
GITLEAKS_INVOCATION_RE = re.compile(r"^[ \t]*gitleaks[ \t]", re.MULTILINE)

# NOTE: PyYAML parses the bare workflow key `on:` as the boolean True, not the
# string "on". OPTIONAL-SECRET and CALLER-WIRING read the trigger key through
# trigger_of(), which tries doc.get("on") and falls back to doc[True].

failures = []


def fail(label, message):
    failures.append("FAIL: {}: {}".format(label, message))


def load(path):
    with open(path, encoding="utf-8") as handle:
        return yaml.safe_load(handle)


caller = load(CALLER)
callee = load(CALLEE)

# Every workflow file, loaded once, in sorted order. The caller and callee are
# reused rather than parsed twice.
_loaded = {os.path.normpath(CALLER): caller, os.path.normpath(CALLEE): callee}
DOCS = []
for _path in sorted(glob.glob(os.path.join(WORKFLOWS_DIR, "*.yml"))
                    + glob.glob(os.path.join(WORKFLOWS_DIR, "*.yaml"))):
    _key = os.path.normpath(_path)
    _doc = _loaded[_key] if _key in _loaded else load(_path)
    DOCS.append((_path, _doc if isinstance(_doc, dict) else {}))


def trigger_of(doc):
    trigger = doc.get("on", doc.get(True))
    return trigger if isinstance(trigger, dict) else {}


def jobs_of(doc):
    jobs = doc.get("jobs") or {}
    return [(jid, body) for jid, body in jobs.items() if isinstance(body, dict)]


def steps_of(job_body):
    return [s for s in (job_body.get("steps") or []) if isinstance(s, dict)]


# ── 1. PERMISSIONS-CALLER ────────────────────────────────────────────────────
# The caller's permission set is the CEILING for the called workflow. A grant
# made only in the callee yields a 403 on every upload.
caller_jobs = caller.get("jobs") or {}
security_job = caller_jobs.get("security")
if not isinstance(security_job, dict):
    fail("PERMISSIONS-CALLER", "jobs.security not found in {}".format(CALLER))
else:
    jp = security_job.get("permissions")
    if not isinstance(jp, dict):
        fail("PERMISSIONS-CALLER",
             "jobs.security.permissions is not a mapping (got {!r})".format(jp))
    else:
        if jp.get("security-events") != "write":
            fail("PERMISSIONS-CALLER",
                 "security-events: write missing from jobs.security.permissions")
        if jp.get("contents") != "read":
            fail("PERMISSIONS-CALLER",
                 "contents: read missing from jobs.security.permissions — a job-level "
                 "block REPLACES the workflow-level set, so dropping it breaks checkout")

# ── 2. PERMISSIONS-CALLEE ────────────────────────────────────────────────────
# The callee's block is an explicit FULL set. Leaving it at contents: read
# downgrades the caller's grant back out.
wp = callee.get("permissions")
if not isinstance(wp, dict):
    fail("PERMISSIONS-CALLEE",
         "top-level permissions is not a mapping (got {!r})".format(wp))
else:
    if wp.get("security-events") != "write":
        fail("PERMISSIONS-CALLEE",
             "security-events: write missing from the top-level permissions block")
    if wp.get("contents") != "read":
        fail("PERMISSIONS-CALLEE",
             "contents: read missing from the top-level permissions block")

# ── 3. PERMISSIONS-FORBIDDEN ─────────────────────────────────────────────────
for path, doc in DOCS:
    blocks = [("{} workflow-level".format(path), doc.get("permissions"))]
    for jid, body in jobs_of(doc):
        blocks.append(("{} jobs.{}".format(path, jid), body.get("permissions")))
    for label, perms in blocks:
        if perms is None:
            continue
        if isinstance(perms, str):
            if perms in BLANKET_VALUES:
                fail("PERMISSIONS-FORBIDDEN",
                     "{} uses the blanket value {!r}".format(label, perms))
            continue
        if not isinstance(perms, dict):
            fail("PERMISSIONS-FORBIDDEN",
                 "{} permissions is neither a mapping nor a string: {!r}".format(label, perms))
            continue
        for scope, value in FORBIDDEN_SCOPES:
            if perms.get(scope) == value:
                fail("PERMISSIONS-FORBIDDEN",
                     "{} grants {}: {}".format(label, scope, value))

# ── 4. SHA-PIN (ADR-004) ─────────────────────────────────────────────────────
# Job-level `uses:` is walked too: a local `./.github/...` reference carries no
# @ and is skipped, but a future org/repo reusable-workflow reference must be
# pinned like any other.
for path, doc in DOCS:
    refs = []
    for jid, body in jobs_of(doc):
        if body.get("uses"):
            refs.append(("{} jobs.{}.uses".format(path, jid), str(body["uses"])))
        for idx, step in enumerate(steps_of(body)):
            if step.get("uses"):
                refs.append(("{} jobs.{}.steps[{}]".format(path, jid, idx), str(step["uses"])))
    for label, value in refs:
        if "@" not in value:
            continue
        ref = value.rsplit("@", 1)[1]
        if not SHA_RE.match(ref):
            fail("SHA-PIN",
                 "{} is not pinned to a full 40-character lowercase hex SHA: {}".format(label, value))

# ── 5/6/7/8/9. Step-level checks ─────────────────────────────────────────────
categories = {}
artifact_names = {}

for path, doc in DOCS:
    for jid, body in jobs_of(doc):
        steps = steps_of(body)
        for idx, step in enumerate(steps):
            uses = str(step.get("uses") or "")
            with_ = step.get("with") or {}
            if not isinstance(with_, dict):
                with_ = {}
            label = "{} jobs.{}.steps[{}] ({})".format(
                path, jid, idx, step.get("name") or uses or "unnamed")

            # 5. SARIF-CATEGORY
            if "codeql-action/upload-sarif" in uses:
                category = with_.get("category")
                if not category:
                    fail("SARIF-CATEGORY", "{} has no with.category".format(label))
                else:
                    categories.setdefault(str(category), []).append(label)
                if not step.get("id"):
                    fail("SARIF-CATEGORY",
                         "{} has no id: — UPLOAD-VERIFY-PAIRING cannot guard it".format(label))
                if step.get("continue-on-error") is not True:
                    fail("SARIF-CATEGORY",
                         "{} lacks continue-on-error: true (ADR-001)".format(label))

            # 6. ARTIFACT-RETENTION + 7. ARTIFACT-PATH-SAFETY
            if "actions/upload-artifact" in uses:
                name = with_.get("name")
                if not name:
                    fail("ARTIFACT-RETENTION", "{} has no with.name".format(label))
                else:
                    artifact_names.setdefault(str(name), []).append(label)
                if step.get("continue-on-error") is not True:
                    fail("ARTIFACT-RETENTION",
                         "{} lacks continue-on-error: true (ADR-001)".format(label))
                retention = with_.get("retention-days")
                # `type(...) is int` on purpose: bool is a subclass of int and
                # `retention-days: true` must not read as 1.
                if type(retention) is not int or not (1 <= retention <= 90):
                    fail("ARTIFACT-RETENTION",
                         "{} retention-days must be an int in 1..90 (90 is the ceiling without "
                         "a repo-settings change), got {!r}".format(label, retention))

                raw_path = str(with_.get("path") or "")
                path_lines = [ln.strip() for ln in raw_path.splitlines() if ln.strip()]
                if not path_lines:
                    fail("ARTIFACT-PATH-SAFETY",
                         "{} has no with.path — an absent path would make this check vacuous".format(label))
                for line in path_lines:
                    # `**` is tested separately: it is permitted by the
                    # character class below (it contains `*`) but is exactly
                    # the recursive sweep the invariant forbids.
                    if "**" in line or not ARTIFACT_PATH_RE.match(line):
                        fail("ARTIFACT-PATH-SAFETY",
                             "{} path line {!r} is not an anchored *.json / *.sarif basename "
                             "(no directory component, no leading /, no **)".format(label, line))

            # 9. REDACT-RETAINED
            run = str(step.get("run") or "")
            if GITLEAKS_INVOCATION_RE.search(run) and "--redact" not in run:
                fail("REDACT-RETAINED",
                     "{} invokes gitleaks without --redact — its report becomes a "
                     "world-downloadable artifact".format(label))

        # 8. UPLOAD-VERIFY-PAIRING
        # The permanent guard on ADR-001's blind spot: continue-on-error hides
        # a failed upload, so every id'd upload must be read back by a LATER
        # step in the SAME job. Vacuous until 17-03/17-04 add upload steps.
        for idx, step in enumerate(steps):
            uses = str(step.get("uses") or "")
            is_upload = ("codeql-action/upload-sarif" in uses
                         or "actions/upload-artifact" in uses)
            step_id = step.get("id")
            if not (is_upload and step_id):
                continue
            needle = "steps.{}.outcome".format(step_id)
            paired = any(needle in str(later.get("run") or "") for later in steps[idx + 1:])
            if not paired:
                fail("UPLOAD-VERIFY-PAIRING",
                     "{} jobs.{}: upload step id={} has no later step in the same job whose "
                     "run reads {}".format(path, jid, step_id, needle))

# Uniqueness. Artifact names must be unique (upload-artifact v4+ fails on a
# duplicate name); SARIF categories must be unique or one upload overwrites
# another's results in the Security tab.
for check, kind, bucket in (("SARIF-CATEGORY", "category", categories),
                            ("ARTIFACT-RETENTION", "artifact name", artifact_names)):
    for value, labels in sorted(bucket.items()):
        if len(labels) > 1:
            fail(check, "duplicate {} {!r} used by: {}".format(kind, value, ", ".join(labels)))

# ── 10. JOB-SHAPE (regression guard inherited from 16-04, split in Phase 27) ─
# The five scan jobs must exist, stay fully parallel (no needs:) and keep their
# frozen names in SCAN_JOB_IDS order. Every other job id must be one of the
# allow-listed side-channel jobs, which MAY carry needs:.
callee_jobs = callee.get("jobs") or {}
for jid in SCAN_JOB_IDS:
    if not isinstance(callee_jobs.get(jid), dict):
        fail("JOB-SHAPE", "{} has no scan job {!r}".format(CALLEE, jid))
for jid in SCAN_JOB_IDS:
    body = callee_jobs.get(jid)
    if isinstance(body, dict) and "needs" in body:
        fail("JOB-SHAPE",
             "jobs.{} declares needs: — the scan jobs must stay fully parallel".format(jid))
observed_names = [(callee_jobs.get(jid) or {}).get("name") if isinstance(callee_jobs.get(jid), dict)
                  else None for jid in SCAN_JOB_IDS]
if observed_names != FROZEN_JOB_NAMES:
    fail("JOB-SHAPE",
         "check-run names drifted from the frozen set Phase 18 hard-codes: "
         "{!r} != {!r}".format(observed_names, FROZEN_JOB_NAMES))
for jid in callee_jobs:
    if jid not in SCAN_JOB_IDS and jid not in SIDE_CHANNEL_JOB_IDS:
        fail("JOB-SHAPE",
             "{} declares job {!r}, which is neither a scan job {!r} nor an allow-listed "
             "side-channel job {!r}".format(CALLEE, jid, SCAN_JOB_IDS, SIDE_CHANNEL_JOB_IDS))

# ── 11. SIDE-CHANNEL-NOT-REQUIRED (always active, D-03) ──────────────────────
# DefectDojo availability must never block a merge, so neither side-channel
# job may ever enter the branch-ruleset required-check list.
with open(REQUIRED_CHECKS_SCRIPT, encoding="utf-8") as handle:
    required_text = handle.read()
for needle in SIDE_CHANNEL_JOB_NAMES + SIDE_CHANNEL_JOB_IDS:
    if needle in required_text:
        fail("SIDE-CHANNEL-NOT-REQUIRED",
             "{} mentions {!r} — a side-channel job must never be a required check "
             "(Phase 27 D-03)".format(REQUIRED_CHECKS_SCRIPT, needle))


# ── 12-16. Side-channel contract (mandatory for both jobs) ───────────────────
def fail_absent(label, jid):
    fail(label, "jobs.{} is absent from {} — the Phase 27 side-channel job is "
                "mandatory (ADR-024)".format(jid, CALLEE))


def job_if(body):
    return str(body.get("if") or "")


side_jobs = {jid: callee_jobs.get(jid) for jid in SIDE_CHANNEL_JOB_IDS}
present = {jid: body for jid, body in side_jobs.items() if isinstance(body, dict)}

# 12. SIDE-CHANNEL-SHAPE
SHAPE_IF = {
    "defectdojo-import": ("always()", "github.event.action != 'closed'", "vars.DEFECTDOJO_URL != ''"),
    "defectdojo-cleanup": ("github.event.action == 'closed'", "vars.DEFECTDOJO_URL != ''"),
}
for jid in SIDE_CHANNEL_JOB_IDS:
    body = present.get(jid)
    if body is None:
        fail_absent("SIDE-CHANNEL-SHAPE", jid)
        continue
    needs = body.get("needs")
    if jid == "defectdojo-import":
        needs_list = [needs] if isinstance(needs, str) else list(needs or [])
        if set(needs_list) != set(SCAN_JOB_IDS) or len(needs_list) != len(SCAN_JOB_IDS):
            fail("SIDE-CHANNEL-SHAPE",
                 "jobs.{}.needs must be exactly the five scan jobs {!r}, got {!r}".format(
                     jid, SCAN_JOB_IDS, needs))
    elif "needs" in body:
        fail("SIDE-CHANNEL-SHAPE",
             "jobs.{} declares needs: — cleanup runs alone on the closed event".format(jid))
    for fragment in SHAPE_IF[jid]:
        if fragment not in job_if(body):
            fail("SIDE-CHANNEL-SHAPE",
                 "jobs.{}.if does not contain {!r} (got {!r})".format(jid, fragment, job_if(body)))
    job_env = body.get("env")
    if isinstance(job_env, dict):
        for key, value in job_env.items():
            if "secrets." in str(value):
                fail("SIDE-CHANNEL-SHAPE",
                     "jobs.{}.env.{} reads a secret at job level — keep it in step env:".format(jid, key))
    elif job_env is not None:
        fail("SIDE-CHANNEL-SHAPE", "jobs.{}.env is not a mapping: {!r}".format(jid, job_env))
    for idx, step in enumerate(steps_of(body)):
        if "shell" in step:
            fail("SIDE-CHANNEL-SHAPE",
                 "jobs.{}.steps[{}] declares shell: — keep the default bash -eo pipefail".format(jid, idx))

# 13. OPTIONAL-SECRET
# Unconditional: both callers now pass DEFECTDOJO_API_TOKEN (CALLER-WIRING), and
# passing an undeclared secret to a reusable workflow is an error, so the
# declaration must exist whether or not the side-channel jobs do. Absent jobs
# are reported under SIDE-CHANNEL-SHAPE and the other per-job checks.
wc = trigger_of(callee).get("workflow_call")
wc = wc if isinstance(wc, dict) else {}
secrets_decl = wc.get("secrets")
secrets_decl = secrets_decl if isinstance(secrets_decl, dict) else {}
token = secrets_decl.get("DEFECTDOJO_API_TOKEN")
if not isinstance(token, dict):
    fail("OPTIONAL-SECRET",
         "{} on.workflow_call.secrets.DEFECTDOJO_API_TOKEN is not declared".format(CALLEE))
elif token.get("required") is not False:
    fail("OPTIONAL-SECRET",
         "on.workflow_call.secrets.DEFECTDOJO_API_TOKEN.required must be false, got {!r} — "
         "a required secret breaks every caller that has not opted in".format(token.get("required")))

# 14. NO-INTERPOLATION
for jid in SIDE_CHANNEL_JOB_IDS:
    body = present.get(jid)
    if body is None:
        fail_absent("NO-INTERPOLATION", jid)
        continue
    for idx, step in enumerate(steps_of(body)):
        if "${{" in str(step.get("run") or ""):
            fail("NO-INTERPOLATION",
                 "jobs.{}.steps[{}] ({}) run: contains ${{{{ }}}} — pass values through step env: "
                 "only".format(jid, idx, step.get("id") or step.get("name") or "unnamed"))

# 15. IMPORT-VERIFY-PAIRING
# Like UPLOAD-VERIFY-PAIRING, but the later step reads the outcome through its
# env: (the run: body may not interpolate — see NO-INTERPOLATION).
for jid in SIDE_CHANNEL_JOB_IDS:
    body = present.get(jid)
    if body is None:
        fail_absent("IMPORT-VERIFY-PAIRING", jid)
        continue
    steps = steps_of(body)
    for idx, step in enumerate(steps):
        if step.get("continue-on-error") is not True:
            continue
        step_id = step.get("id")
        if not step_id:
            fail("IMPORT-VERIFY-PAIRING",
                 "jobs.{}.steps[{}] has continue-on-error: true but no id: — nothing can "
                 "read its outcome".format(jid, idx))
            continue
        needle = "steps.{}.outcome".format(step_id)
        paired = False
        for later in steps[idx + 1:]:
            if later.get("continue-on-error") is True:
                continue
            env = later.get("env")
            if isinstance(env, dict) and any(needle in str(v) for v in env.values()):
                paired = True
                break
        if not paired:
            fail("IMPORT-VERIFY-PAIRING",
                 "jobs.{}: step id={} has continue-on-error: true and no later red step "
                 "whose env: reads {}".format(jid, step_id, needle))

# 16. INSECURE-WARNING (D-18)
for jid, step_id in (("defectdojo-import", "dd-import"), ("defectdojo-cleanup", "dd-delete")):
    body = present.get(jid)
    if body is None:
        fail_absent("INSECURE-WARNING", jid)
        continue
    matches = [s for s in steps_of(body) if s.get("id") == step_id]
    if not matches:
        fail("INSECURE-WARNING", "jobs.{} has no step id={}".format(jid, step_id))
        continue
    run = str(matches[0].get("run") or "")
    for fragment in ("DD_INSECURE", "::warning::"):
        if fragment not in run:
            fail("INSECURE-WARNING",
                 "jobs.{} step {} run: does not contain {!r} — the insecure-TLS path must be "
                 "loud".format(jid, step_id, fragment))

# ── 17. SCAN-JOB-CLOSED-SKIP (D-15) ──────────────────────────────────────────
# pr-security.yml subscribes to `closed` only to fire defectdojo-cleanup. Each
# scan job must skip on it with exactly this job-level if:, or a closed PR
# re-runs all five scans for nothing. On schedule and workflow_dispatch
# github.event.action is empty, so the scans still run there.
CLOSED_SKIP_IF = "github.event.action != 'closed'"
for jid in SCAN_JOB_IDS:
    body = callee_jobs.get(jid)
    if not isinstance(body, dict):
        continue  # already reported by JOB-SHAPE
    got = str(body.get("if") or "").strip()
    if got != CLOSED_SKIP_IF:
        fail("SCAN-JOB-CLOSED-SKIP",
             "jobs.{}.if must be exactly {!r}, got {!r}".format(jid, CLOSED_SKIP_IF, got))

# ── 18. CALLER-WIRING (D-12, D-15) ───────────────────────────────────────────
# The callee can use the token only if each caller passes it, and cleanup can
# fire only if pr-security.yml subscribes to `closed`. Listing types: REPLACES
# the default set, so a list missing any default silently stops PR scanning
# while every required context sits pending (RESEARCH Pitfall 2).
PR_TYPES = ["opened", "synchronize", "reopened", "closed"]
TOKEN_PASS = "${{ secrets.DEFECTDOJO_API_TOKEN }}"

pr_trigger = trigger_of(caller).get("pull_request")
pr_types = pr_trigger.get("types") if isinstance(pr_trigger, dict) else None
if pr_types != PR_TYPES:
    fail("CALLER-WIRING",
         "{} on.pull_request.types must be exactly {!r}, got {!r}".format(CALLER, PR_TYPES, pr_types))

scheduled = None
if os.path.isfile(SCHEDULED):
    scheduled = load(SCHEDULED)
    scheduled = scheduled if isinstance(scheduled, dict) else {}
else:
    fail("CALLER-WIRING",
         "{} is missing — the daily default-branch caller is part of the Phase 27 "
         "bundle (D-14, D-15)".format(SCHEDULED))

for path, doc in ((CALLER, caller), (SCHEDULED, scheduled)):
    if doc is None:
        continue
    job = (doc.get("jobs") or {}).get("security")
    if not isinstance(job, dict):
        fail("CALLER-WIRING", "{} has no jobs.security".format(path))
        continue
    secrets_pass = job.get("secrets")
    if isinstance(secrets_pass, str):
        fail("CALLER-WIRING",
             "{} jobs.security.secrets is {!r} — pass DEFECTDOJO_API_TOKEN explicitly, never "
             "`secrets: inherit` (D-12)".format(path, secrets_pass))
    elif not isinstance(secrets_pass, dict):
        fail("CALLER-WIRING",
             "{} jobs.security.secrets must be a mapping with only DEFECTDOJO_API_TOKEN, "
             "got {!r}".format(path, secrets_pass))
    else:
        if sorted(secrets_pass) != ["DEFECTDOJO_API_TOKEN"]:
            fail("CALLER-WIRING",
                 "{} jobs.security.secrets keys must be exactly ['DEFECTDOJO_API_TOKEN'], "
                 "got {!r}".format(path, sorted(secrets_pass)))
        value = str(secrets_pass.get("DEFECTDOJO_API_TOKEN") or "").strip()
        if value != TOKEN_PASS:
            fail("CALLER-WIRING",
                 "{} jobs.security.secrets.DEFECTDOJO_API_TOKEN must be {!r}, got {!r}".format(
                     path, TOKEN_PASS, value))
    if "with" in job:
        fail("CALLER-WIRING",
             "{} jobs.security declares with: — gate_mode and DEFECTDOJO_* are read from the "
             "caller repo's vars by the callee, never passed".format(path))

if scheduled is not None:
    sched_trigger = trigger_of(scheduled)
    entries = sched_trigger.get("schedule")
    entries = [e for e in entries if isinstance(e, dict)] if isinstance(entries, list) else []
    if not any(str(e.get("cron")) == "0 6 * * *" and e.get("timezone") == "America/Toronto"
               for e in entries):
        fail("CALLER-WIRING",
             "{} on.schedule has no entry with cron '0 6 * * *' and timezone "
             "'America/Toronto', got {!r}".format(SCHEDULED, sched_trigger.get("schedule")))
    if "workflow_dispatch" not in sched_trigger:
        fail("CALLER-WIRING", "{} on has no workflow_dispatch key".format(SCHEDULED))

# ── 19. SCHEME (D-18, CR-01) ─────────────────────────────────────────────────
# A plain-http DEFECTDOJO_URL would send the instance-wide staff token in
# cleartext. Both bodies must refuse any non-https URL, and must do so BEFORE
# the token header file is written; every curl must be pinned to https. A
# presence-only substring check is the WR-05 weakness, so the refusal's
# position relative to the header write is asserted too.
SCHEME_REFUSAL = 'startswith("https://")'
SCHEME_FRAGMENTS = (SCHEME_REFUSAL, '"--proto", "=https"', '"--proto-redir", "=https"')
HEADER_WRITE = "write_private(hdr_path"
for jid, step_id in (("defectdojo-import", "dd-import"), ("defectdojo-cleanup", "dd-delete")):
    body = present.get(jid)
    if body is None:
        fail_absent("SCHEME", jid)
        continue
    matches = [s for s in steps_of(body) if s.get("id") == step_id]
    if not matches:
        fail("SCHEME", "jobs.{} has no step id={}".format(jid, step_id))
        continue
    run = str(matches[0].get("run") or "")
    for fragment in SCHEME_FRAGMENTS:
        if fragment not in run:
            fail("SCHEME",
                 "jobs.{} step {} run: does not contain {!r} — DEFECTDOJO_URL must be refused "
                 "unless https:// and every curl pinned to https (CR-01)".format(jid, step_id, fragment))
    refusal_at = run.find(SCHEME_REFUSAL)
    header_at = run.find(HEADER_WRITE)
    if refusal_at < 0 or header_at < 0 or refusal_at >= header_at:
        fail("SCHEME",
             "jobs.{} step {} run: the https refusal ({!r}) must precede the header write ({!r}) "
             "— the token must never be staged for a non-https URL (CR-01)".format(
                 jid, step_id, SCHEME_REFUSAL, HEADER_WRITE))

# PERMISSIONS-CALLER, PERMISSIONS-CALLEE, PERMISSIONS-FORBIDDEN, SHA-PIN,
# SARIF-CATEGORY, ARTIFACT-RETENTION, ARTIFACT-PATH-SAFETY, UPLOAD-VERIFY-PAIRING,
# REDACT-RETAINED, JOB-SHAPE, SIDE-CHANNEL-NOT-REQUIRED, SIDE-CHANNEL-SHAPE,
# OPTIONAL-SECRET, NO-INTERPOLATION, IMPORT-VERIFY-PAIRING, INSECURE-WARNING,
# SCAN-JOB-CLOSED-SKIP, CALLER-WIRING, SCHEME.
CHECK_COUNT = 19

if failures:
    for line in failures:
        print(line)
    print("FAILED - {} check(s)".format(len(failures)))
    sys.exit(1)

print("PASS - {} checks, 0 failures".format(CHECK_COUNT))
sys.exit(0)
PY

exit "$rc"
