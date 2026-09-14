#!/usr/bin/env bash
set -euo pipefail

# check-adoption-guide.sh — offline standing gate for docs/adoption-guide.md,
# the consumer-facing rollout doc Phase 20 ships. Every failure mode in this
# gate's domain fails SILENTLY — a hyphen typed where U+2014 belongs produces
# a required check that sits permanently pending in a consumer repo, with no
# runtime signal anywhere.
#
# DERIVATION, NOT RETYPING: the five required check-run contexts are composed
# from the caller job id (repos/security-platform/.github/workflows/
# pr-security.yml, jobs.security.name, frozen at "security") and the five
# `name:` values on repos/security-platform/.github/workflows/security.yml's
# jobs (jobs.<id>.name). A hard-coded comparison copy in this script would be
# exactly the tampering vector T-20-12 exists to prevent.
#
# Exit codes — the same three-way contract as check-workflow-uploads.sh:
#   0  all checks passed
#   1  at least one assertion failed, including "guide not found" — the
#      guide is a pending deliverable at this commit, not an infra problem
#   2  the canonical host clone repos/security-platform/.github/workflows/
#      is absent, so the frozen strings cannot be derived — an
#      INFRASTRUCTURE signal; never fall back to hard-coded strings
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/check-adoption-guide.sh [path/to/guide.md]
#
# AT THIS PLAN'S COMMIT (20-02) docs/adoption-guide.md does not exist yet —
# this gate is EXPECTED to exit 1 with "guide not found" as its first
# reported failure. See 20-02-SUMMARY.md.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

GUIDE_PATH="${1:-docs/adoption-guide.md}"
HOST_WORKFLOWS_DIR="repos/security-platform/.github/workflows"
HOST_SECURITY_YML="${HOST_WORKFLOWS_DIR}/security.yml"
HOST_PR_SECURITY_YML="${HOST_WORKFLOWS_DIR}/pr-security.yml"

# Preflight — distinct exit code 2. The frozen strings cannot be derived at
# all without the canonical host clone; this is never conflated with a guide
# defect, and there is deliberately no hard-coded fallback.
if [ ! -d "$HOST_WORKFLOWS_DIR" ]; then
  echo "PREFLIGHT FAIL: ${HOST_WORKFLOWS_DIR} absent — cannot derive the frozen check-run contexts. This is an infrastructure signal (canonical host clone missing), not a guide defect."
  exit 2
fi
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "PREFLIGHT FAIL: python3 yaml module (pyyaml) not available — install with: python3 -m pip install pyyaml"
  exit 2
fi

echo "check-adoption-guide: deriving frozen contexts from ${HOST_SECURITY_YML} and ${HOST_PR_SECURITY_YML}"

rc=0
GUIDE_PATH="$GUIDE_PATH" python3 - <<'PY' || rc=$?
import os
import re
import subprocess
import sys

import yaml

GUIDE_PATH = os.environ["GUIDE_PATH"]
HOST_SECURITY_YML = "repos/security-platform/.github/workflows/security.yml"
HOST_PR_SECURITY_YML = "repos/security-platform/.github/workflows/pr-security.yml"

failures = []
passed = 0


def fail(label, message):
    failures.append("FAIL: {}: {}".format(label, message))


def ok(label, message):
    global passed
    passed += 1
    print("PASS: {}: {}".format(label, message))


def load(path):
    with open(path, encoding="utf-8") as handle:
        return yaml.safe_load(handle)


callee = load(HOST_SECURITY_YML)
caller = load(HOST_PR_SECURITY_YML)

callee_jobs = callee.get("jobs") or {}
job_names = [body.get("name") for body in callee_jobs.values() if isinstance(body, dict)]
job_names = [n for n in job_names if n]

caller_jobs = caller.get("jobs") or {}
caller_job_names = [body.get("name") for body in caller_jobs.values() if isinstance(body, dict)]
caller_job_names = [n for n in caller_job_names if n]

if len(job_names) != 5:
    fail("DERIVE-CONTEXTS", "expected exactly 5 job name: values in {}, found {}: {!r}".format(
        HOST_SECURITY_YML, len(job_names), job_names))
if len(caller_job_names) != 1:
    fail("DERIVE-CONTEXTS", "expected exactly 1 job name: value in {}, found {}: {!r}".format(
        HOST_PR_SECURITY_YML, len(caller_job_names), caller_job_names))

if failures:
    for line in failures:
        print(line)
    print("check-adoption-guide: cannot proceed — frozen strings failed to derive")
    sys.exit(1)

caller_job_id = caller_job_names[0]
contexts = ["{} / {}".format(caller_job_id, name) for name in job_names]
print("DERIVED contexts ({}):".format(len(contexts)))
for c in contexts:
    print("  {!r}".format(c))
    dump = " ".join("{:02x}".format(b) for b in c.encode("utf-8"))
    print("    bytes: {}".format(dump))

ok("DERIVE-CONTEXTS", "derived {} contexts from {} job name: values + caller job id {!r}".format(
    len(contexts), HOST_SECURITY_YML, caller_job_id))

# ── GUIDE EXISTENCE ──────────────────────────────────────────────────────────
if not os.path.isfile(GUIDE_PATH):
    fail("GUIDE-EXISTS", "{} not found — the adoption guide is a pending deliverable".format(GUIDE_PATH))
    for line in failures:
        print(line)
    print("check-adoption-guide: PASSED {} / FAILED {}".format(passed, len(failures)))
    sys.exit(1)

ok("GUIDE-EXISTS", "{} found".format(GUIDE_PATH))

with open(GUIDE_PATH, encoding="utf-8") as handle:
    guide_text = handle.read()
guide_lines = guide_text.splitlines()

# ── CONTEXT-PRESENCE + EM-DASH-SEPARATOR ────────────────────────────────────
EM_DASH = "—"
for ctx in contexts:
    if ctx not in guide_text:
        fail("CONTEXT-PRESENCE", "derived context {!r} not found verbatim in {}".format(ctx, GUIDE_PATH))
        continue
    # The separator between caller job id and job name must be U+2014.
    job_name = ctx.split(" / ", 1)[1]
    if EM_DASH not in job_name:
        # Not every job name necessarily contains an em dash by construction,
        # but every one measured at this commit does — assert it explicitly.
        fail("CONTEXT-EM-DASH", "context {!r} job-name portion has no U+2014 separator".format(ctx))
    else:
        ok("CONTEXT-EM-DASH", "context {!r} carries U+2014 (e2 80 94) as its separator".format(ctx))

if not any(l.startswith("FAIL: CONTEXT-PRESENCE") for l in failures):
    ok("CONTEXT-PRESENCE", "all {} derived contexts found verbatim in {}".format(len(contexts), GUIDE_PATH))

# ── SIXTH-CONTEXT (no bare "security / ..." beyond the five) ────────────────
all_security_slash = set(re.findall(r"security / [^\n`]+", guide_text))
# Trim trailing punctuation/backtick noise conservatively by comparing against
# known contexts; anything not in the derived set is a candidate sixth string.
unexpected = sorted(s for s in all_security_slash if s.strip() not in contexts and
                     not any(s.strip().startswith(c) for c in contexts))
if unexpected:
    fail("SIXTH-CONTEXT", "guide contains 'security / ...' string(s) not in the derived five: {!r}".format(unexpected))
else:
    ok("SIXTH-CONTEXT", "no sixth 'security / ...' context found")

# ── NO-OCC-GITHUB (RESEARCH C-1: dead path) ─────────────────────────────────
if "OCC-github" in guide_text:
    fail("NO-OCC-GITHUB", "'OCC-github' appears in the guide — dead path, org 404s")
else:
    ok("NO-OCC-GITHUB", "'OCC-github' does not appear in the guide")

# ── REUSABLE-WORKFLOW-REF ────────────────────────────────────────────────────
ref_pattern = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml@[A-Za-z0-9_.-]+")
allowed_refs = re.compile(
    r"^OttawaCloudConsulting/security-platform/\.github/workflows/security\.yml@(v1|v1\.0\.0)$")
bad_refs = []
for m in ref_pattern.finditer(guide_text):
    ref = m.group(0)
    if not allowed_refs.match(ref):
        bad_refs.append(ref)
if bad_refs:
    fail("REUSABLE-WORKFLOW-REF", "non-canonical reusable-workflow reference(s): {!r}".format(sorted(set(bad_refs))))
else:
    ok("REUSABLE-WORKFLOW-REF", "every reusable-workflow reference is @v1 or @v1.0.0 on the canonical repo/path")

# ── RAW-GITHUBUSERCONTENT-PIN ────────────────────────────────────────────────
raw_urls = re.findall(r"https://raw\.githubusercontent\.com/\S+", guide_text)
bad_raw = [u for u in raw_urls if "/main/" in u or "/v1/" not in u]
if bad_raw:
    fail("RAW-GITHUBUSERCONTENT-PIN", "raw.githubusercontent.com URL(s) not pinned at /v1/: {!r}".format(bad_raw))
elif raw_urls:
    ok("RAW-GITHUBUSERCONTENT-PIN", "all {} raw.githubusercontent.com URL(s) pinned at /v1/".format(len(raw_urls)))
else:
    ok("RAW-GITHUBUSERCONTENT-PIN", "no raw.githubusercontent.com URLs present")

# ── BANNED-PATTERNS (|| true, --config auto) outside labelled anti-pattern blocks ──
# Exclude comment/prose lines that are inside a fenced block explicitly
# labelled as an anti-pattern example (a line containing "anti-pattern" or
# "DO NOT" within 3 lines above a fence start).
BANNED = ["|| true", "--config auto"]
lines = guide_lines
anti_pattern_zones = set()
in_fence = False
fence_start = None
recent_anti_label = False
for i, line in enumerate(lines):
    if re.match(r"^\s*```", line):
        if not in_fence:
            in_fence = True
            fence_start = i
            # look back up to 3 lines for an anti-pattern label
            recent_anti_label = any(
                "anti-pattern" in lines[j].lower() or "do not" in lines[j].lower()
                for j in range(max(0, i - 3), i)
            )
            if recent_anti_label:
                anti_pattern_zones.add(fence_start)
        else:
            if recent_anti_label:
                for j in range(fence_start, i + 1):
                    anti_pattern_zones.add(j)
            in_fence = False
            recent_anti_label = False

banned_hits = []
for i, line in enumerate(lines):
    if i in anti_pattern_zones:
        continue
    for pat in BANNED:
        if pat in line:
            banned_hits.append((i + 1, pat, line.strip()))
if banned_hits:
    fail("BANNED-PATTERNS", "banned pattern(s) outside a labelled anti-pattern block: {!r}".format(banned_hits))
else:
    ok("BANNED-PATTERNS", "'|| true' and '--config auto' appear zero times outside labelled anti-pattern blocks")

# ── NO-FIXTURES-DIR (security-platform-only scaffolding) ────────────────────
fixtures_hits = []
for i, line in enumerate(lines):
    if "fixtures/" in line:
        lower = line.lower()
        if "security-platform" in lower or "security-platform-only" in lower or "validation" in lower:
            continue
        fixtures_hits.append((i + 1, line.strip()))
if fixtures_hits:
    fail("NO-FIXTURES-DIR", "guide references 'fixtures/' outside a security-platform-only context: {!r}".format(fixtures_hits))
else:
    ok("NO-FIXTURES-DIR", "'fixtures/' never appears outside a sentence naming it security-platform-only")

# ── MARKDOWNLINT ─────────────────────────────────────────────────────────────
if not any(os.access(os.path.join(p, "markdownlint-cli2"), os.X_OK)
           for p in os.environ.get("PATH", "").split(os.pathsep) if p):
    fail("MARKDOWNLINT", "markdownlint-cli2 not found on PATH — cannot verify the guide passes the "
         "enabled rules (MD001, MD009, MD010, MD025, MD034); this is a distinct infra signal from a "
         "guide defect, recorded as a failure rather than a silent skip")
else:
    proc = subprocess.run(["markdownlint-cli2", GUIDE_PATH], capture_output=True, text=True)
    if proc.returncode != 0:
        fail("MARKDOWNLINT", "markdownlint-cli2 reported violation(s) on {}:\n{}".format(
            GUIDE_PATH, (proc.stdout + proc.stderr).strip()))
    else:
        ok("MARKDOWNLINT", "markdownlint-cli2 reports zero violations on {}".format(GUIDE_PATH))

CHECK_LABEL = "check-adoption-guide"

if failures:
    for line in failures:
        print(line)
    print("{}: PASSED {} / FAILED {}".format(CHECK_LABEL, passed, len(failures)))
    sys.exit(1)

print("{}: PASSED {} / FAILED 0".format(CHECK_LABEL, passed))
sys.exit(0)
PY

exit "$rc"
