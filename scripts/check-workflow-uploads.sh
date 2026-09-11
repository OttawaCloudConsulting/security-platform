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
# It parses BOTH workflow files with PyYAML and reports EVERY failure rather
# than stopping at the first, so one run tells you the whole story.
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

echo "check-workflow-uploads: parsing .github/workflows/pr-security.yml and .github/workflows/security.yml"

# The heredoc delimiter is QUOTED ('PY') on purpose: the python source below
# contains $, * and GitHub ${{ }} expression fragments that an unquoted
# delimiter would let the shell expand before python ever saw them.
rc=0
python3 - <<'PY' || rc=$?
import re
import sys

import yaml

CALLER = ".github/workflows/pr-security.yml"
CALLEE = ".github/workflows/security.yml"

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
# string "on". Nothing below reads the trigger key; if you ever need it, index
# it as doc[True] or doc.get("on") defensively.

failures = []


def fail(label, message):
    failures.append("FAIL: {}: {}".format(label, message))


def load(path):
    with open(path, encoding="utf-8") as handle:
        return yaml.safe_load(handle)


caller = load(CALLER)
callee = load(CALLEE)
DOCS = ((CALLER, caller), (CALLEE, callee))


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

# ── 10. JOB-SHAPE (regression guard inherited from 16-04) ────────────────────
callee_jobs = callee.get("jobs") or {}
if len(callee_jobs) != 5:
    fail("JOB-SHAPE",
         "{} declares {} job(s); the parallel scan set is exactly 5".format(CALLEE, len(callee_jobs)))
for jid, body in callee_jobs.items():
    if isinstance(body, dict) and "needs" in body:
        fail("JOB-SHAPE",
             "jobs.{} declares needs: — the scan jobs must stay fully parallel".format(jid))
observed_names = [(body or {}).get("name") for body in callee_jobs.values()]
if observed_names != FROZEN_JOB_NAMES:
    fail("JOB-SHAPE",
         "check-run names drifted from the frozen set Phase 18 hard-codes: "
         "{!r} != {!r}".format(observed_names, FROZEN_JOB_NAMES))

CHECK_COUNT = 10

if failures:
    for line in failures:
        print(line)
    print("FAILED - {} check(s)".format(len(failures)))
    sys.exit(1)

print("PASS - {} checks, 0 failures".format(CHECK_COUNT))
sys.exit(0)
PY

exit "$rc"
