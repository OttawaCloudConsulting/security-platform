#!/usr/bin/env bash
set -euo pipefail

# check-detector-parity.sh — offline standing gate for Phase 20's inlining of
# the npm/Python/Terraform detect steps into the security.yml workflow body,
# plus the independent Dockerfile-pathspec measurement (RESEARCH assumption
# A4).
#
# WHY THIS EXISTS. Every failure mode in this gate's domain fails SILENTLY
# GREEN: a wrong pathspec prints a "SKIP:" line on a repository that really
# does have dependencies, and a detect step that quietly still shells out to
# scripts/detect-*.sh (rather than running the body CI actually executes)
# would let this harness certify logic nobody runs. This script extracts the
# `run:` body of each detect step BY JOB AND STEP ID from the committed YAML
# (the 16-04 technique) and executes it under the runner's own default shell
# semantics — `bash -e`, NOT `bash -euo pipefail` — because security.yml
# declares no `shell:` key and no `defaults:` block anywhere.
#
# Exit codes — the same three-way contract as check-workflow-uploads.sh:
#   0  every check passed
#   1  at least one assertion failed  (a workflow defect — fix the YAML)
#   2  preflight failed: pyyaml is not importable (an INFRASTRUCTURE problem
#      on this machine, not a workflow defect). No regex fallback — a silent
#      fallback that "mostly works" is exactly the failure mode this gate
#      exists to prevent.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/check-detector-parity.sh
#
# AT THIS PLAN'S COMMIT (20-02) all four detect steps (npm, py, tf, docker)
# still delegate to their scripts, or in the container job's case have no
# detect step at all — this gate is EXPECTED to be red. Plan 03 inlines the
# bodies and turns it green. See 20-02-SUMMARY.md for the predicted-vs-
# observed failure shape recorded at this commit.
#
# A4 NOTE: the pathspec assertion below deliberately does NOT use the naive
# three-item form `'*Dockerfile' '*Dockerfile.*' '*.dockerfile'` sketched in
# 20-02-PLAN.md's prose. Measured (in a scratch repo, see 20-02-SUMMARY.md):
# git's default pathspec wildcards cross '/', so `'*Dockerfile.*'` also
# matches a decoy path like `docs/notes-Dockerfile.md` (`*`=`docs/notes-`,
# `Dockerfile.`, `*`=`md`) — five paths, not the intended four. The five-item
# form below (`'Dockerfile' '*/Dockerfile' 'Dockerfile.*' '*/Dockerfile.*'
# '*.dockerfile'`) is the corrected pathspec that plan 03 must copy into the
# inlined Docker detect step; it is what THIS gate asserts, and it measures
# clean (zero A4 failures). Do not "simplify" this back to the three-item
# form — it silently reintroduces the decoy match.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Preflight. Distinct exit code 2 — see the header.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "PREFLIGHT FAIL: python3 yaml module (pyyaml) not available — install with: python3 -m pip install pyyaml"
  exit 2
fi

echo "check-detector-parity: parsing .github/workflows/security.yml, extracting step run bodies by job+id"

rc=0
python3 - <<'PY' || rc=$?
import os
import re
import shutil
import subprocess
import sys
import tempfile

import yaml

WORKFLOW = ".github/workflows/security.yml"
REPO_ROOT = os.getcwd()

with open(WORKFLOW, encoding="utf-8") as handle:
    doc = yaml.safe_load(handle)

failures = []
passed = 0


def fail(label, message):
    failures.append("FAIL: {}: {}".format(label, message))


def ok(label, message):
    global passed
    passed += 1
    print("PASS: {}: {}".format(label, message))


jobs = doc.get("jobs") or {}


def find_step(job_id, step_id):
    job = jobs.get(job_id)
    if not isinstance(job, dict):
        return None, "job {!r} not found".format(job_id)
    for step in job.get("steps") or []:
        if isinstance(step, dict) and step.get("id") == step_id:
            return step, None
    return None, "step id {!r} not found in job {!r}".format(step_id, job_id)


# ── STEP-ID-EXTRACT ──────────────────────────────────────────────────────────
ECOSYSTEMS = {
    "npm": {"job": "sca", "step_id": "npm", "list_file": "npm-lockfiles.txt",
            "pathspec": ["*package-lock.json"], "detect_script": "scripts/detect-npm.sh"},
    "py": {"job": "sca", "step_id": "py", "list_file": "py-reqs.txt",
           "pathspec": ["*requirements*.txt"], "detect_script": "scripts/detect-python.sh"},
    "tf": {"job": "sca", "step_id": "tf", "list_file": "tf-files.txt",
           "pathspec": ["*.tf"], "detect_script": "scripts/detect-terraform.sh"},
}

steps = {}
for name, meta in ECOSYSTEMS.items():
    step, err = find_step(meta["job"], meta["step_id"])
    if err:
        fail("STEP-ID-EXTRACT", "ecosystem {}: {}".format(name, err))
        steps[name] = None
    else:
        ok("STEP-ID-EXTRACT", "ecosystem {}: found jobs.{}.steps[id={}]".format(
            name, meta["job"], meta["step_id"]))
        steps[name] = step

docker_step, docker_err = find_step("container", "docker")
if docker_err:
    fail("STEP-ID-EXTRACT", "docker: {}".format(docker_err))
else:
    ok("STEP-ID-EXTRACT", "docker: found jobs.container.steps[id=docker]")

# ── NO-SHELL-KEY ─────────────────────────────────────────────────────────────
# The runner's default is `bash -e {0}` only when NO shell: key and NO
# defaults: block exist anywhere in the file. If either appears, this
# harness's "execute under bash -e" premise is unverified and must fail
# loudly rather than silently drift from the runner.
if doc.get("defaults"):
    fail("NO-SHELL-KEY", "top-level defaults: block exists — bash -e assumption invalid")
for jid, jbody in jobs.items():
    if not isinstance(jbody, dict):
        continue
    if jbody.get("defaults"):
        fail("NO-SHELL-KEY", "jobs.{}.defaults exists — bash -e assumption invalid".format(jid))
    for idx, step in enumerate(jbody.get("steps") or []):
        if isinstance(step, dict) and step.get("shell"):
            fail("NO-SHELL-KEY", "jobs.{}.steps[{}] declares shell: {!r}".format(
                jid, idx, step["shell"]))
if not failures:
    ok("NO-SHELL-KEY", "zero shell: keys and zero defaults: blocks — runner uses bash -e {0}")

# ── SOURCE (per ecosystem): git ls-files present, no script delegation, ─────
# discovery pipeline carries || true not on a found= decision line, and the
# list-file name survives verbatim (security.yml:530/592 read these on fd 3).
inlined = {}
for name, meta in ECOSYSTEMS.items():
    step = steps.get(name)
    if step is None:
        inlined[name] = False
        continue
    run = str(step.get("run") or "")
    delegates = "bash scripts/detect-" in run
    has_ls_files = "git ls-files" in run
    if delegates or not has_ls_files:
        fail("SOURCE-{}".format(name.upper()),
             "still delegates to {} (run={!r}) rather than running an inlined body "
             "containing 'git ls-files' — measured at this commit, expected until "
             "plan 03 inlines it".format(meta["detect_script"], run.strip()))
        inlined[name] = False
        continue
    # Only reached once the body is actually inlined (post plan-03).
    inlined[name] = True
    pipe_ok = "|| true" in run
    decision_lines = [ln for ln in run.splitlines() if "found=true" in ln or "found=false" in ln]
    true_on_decision = any("|| true" in ln for ln in decision_lines)
    if not pipe_ok or true_on_decision:
        fail("SOURCE-{}".format(name.upper()),
             "discovery pipeline || true placement wrong (present={}, on-decision-line={})".format(
                 pipe_ok, true_on_decision))
        inlined[name] = False
    if name in ("npm", "py") and meta["list_file"] not in run:
        fail("SOURCE-{}".format(name.upper()),
             "list file name {!r} not found verbatim in the inlined body".format(meta["list_file"]))
    if inlined[name]:
        ok("SOURCE-{}".format(name.upper()), "body is inlined, contains git ls-files, "
           "|| true correctly placed, list-file name intact")

# ── BEHAVIOUR / PARITY (per ecosystem) ──────────────────────────────────────
# Only runnable once a body is actually inlined. While it still delegates,
# recording a fabricated pass would certify logic nobody wrote — record each
# as blocked instead.
GITHUB_OUTPUT_RE = re.compile(r"^([A-Za-z0-9_-]+)=(.*)$")


def run_body(body, cwd, extra_env=None):
    """Execute an extracted step run: body under bash -e, the runner's
    default when no shell: key or defaults: block is present (verified
    above). Returns (returncode, stdout, github_output dict)."""
    fd, out_path = tempfile.mkstemp(prefix="gh-output-")
    os.close(fd)
    open(out_path, "w").close()
    env = dict(os.environ)
    env["GITHUB_OUTPUT"] = out_path
    if extra_env:
        env.update(extra_env)
    proc = subprocess.run(
        ["bash", "-e", "-c", body],
        cwd=cwd, env=env, capture_output=True, text=True,
    )
    outputs = {}
    with open(out_path, encoding="utf-8") as handle:
        for line in handle:
            m = GITHUB_OUTPUT_RE.match(line.rstrip("\n"))
            if m:
                outputs[m.group(1)] = m.group(2)
    os.unlink(out_path)
    return proc.returncode, proc.stdout, outputs


def scratch_repo():
    d = tempfile.mkdtemp(prefix="detector-parity-scratch-")
    subprocess.run(["git", "init", "-q"], cwd=d, check=True)
    subprocess.run(["git", "config", "user.email", "test@test.invalid"], cwd=d, check=True)
    subprocess.run(["git", "config", "user.name", "test"], cwd=d, check=True)
    return d


def git_commit_all(d):
    subprocess.run(["git", "add", "-A"], cwd=d, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "scratch"], cwd=d, check=True)


def write(d, relpath, content=""):
    full = os.path.join(d, relpath)
    os.makedirs(os.path.dirname(full) or d, exist_ok=True)
    with open(full, "w", encoding="utf-8") as handle:
        handle.write(content)


SKIP_STRINGS = {}
for name, meta in ECOSYSTEMS.items():
    script_path = os.path.join(REPO_ROOT, meta["detect_script"])
    with open(script_path, encoding="utf-8") as handle:
        script_src = handle.read()
    m = re.search(r'echo "(SKIP: [^"]+)"', script_src)
    SKIP_STRINGS[name] = m.group(1) if m else None

POSITIVE_FIXTURES = {
    "npm": ["package-lock.json", "sub/package-lock.json"],
    "py": ["requirements.txt", "sub/requirements-dev.txt"],
    "tf": ["main.tf", "sub/other.tf"],
}
NPM_EXCLUSION_FIXTURES = [
    "package-lock.json",
    "node_modules/x/package-lock.json",
    "pkg/node_modules/y/package-lock.json",
]

for name, meta in ECOSYSTEMS.items():
    if not inlined.get(name):
        for check in ("BEHAVIOUR-POSITIVE", "BEHAVIOUR-NEGATIVE", "PARITY"):
            fail("{}-{}".format(check, name.upper()),
                 "not yet inlined — jobs.sca.steps[id={}] still delegates to {}, "
                 "cannot measure the inlined body's behaviour".format(meta["step_id"],
                                                                       meta["detect_script"]))
        continue

    step = steps[name]
    run = str(step.get("run") or "")

    # BEHAVIOUR positive
    d = scratch_repo()
    for f in POSITIVE_FIXTURES[name]:
        write(d, f)
    git_commit_all(d)
    rc_body, out_body, outputs_body = run_body(run, d)
    if "FOUND 2" not in out_body or outputs_body.get("found") != "true":
        fail("BEHAVIOUR-POSITIVE-{}".format(name.upper()),
             "expected stdout containing 'FOUND 2' and found=true, "
             "got rc={} stdout={!r} outputs={!r}".format(rc_body, out_body, outputs_body))
    else:
        ok("BEHAVIOUR-POSITIVE-{}".format(name.upper()), "FOUND 2 / found=true as expected")
    shutil.rmtree(d, ignore_errors=True)

    # BEHAVIOUR negative
    d = scratch_repo()
    write(d, ".gitkeep")
    git_commit_all(d)
    rc_body, out_body, outputs_body = run_body(run, d)
    skip_str = SKIP_STRINGS.get(name)
    if rc_body != 0 or not skip_str or skip_str not in out_body or outputs_body.get("found") != "false":
        fail("BEHAVIOUR-NEGATIVE-{}".format(name.upper()),
             "expected rc=0, byte-exact SKIP string {!r} in stdout, found=false; "
             "got rc={} stdout={!r} outputs={!r}".format(skip_str, rc_body, out_body, outputs_body))
    else:
        ok("BEHAVIOUR-NEGATIVE-{}".format(name.upper()), "rc=0, byte-exact SKIP string, found=false")
    shutil.rmtree(d, ignore_errors=True)

    # PARITY: same positive tree, compare inlined body vs detect-<x>.sh
    d = scratch_repo()
    for f in POSITIVE_FIXTURES[name]:
        write(d, f)
    git_commit_all(d)
    rc_body, out_body, outputs_body = run_body(run, d)
    list_path = os.path.join(d, meta["list_file"])
    rc_script, out_script, outputs_script = run_body(
        "bash {} {}".format(os.path.join(REPO_ROOT, meta["detect_script"]), meta["list_file"]), d)
    if out_body.strip() != out_script.strip() or outputs_body.get("found") != outputs_script.get("found"):
        fail("PARITY-{}".format(name.upper()),
             "inlined body and {} diverge: stdout equal={}, found equal={}".format(
                 meta["detect_script"], out_body.strip() == out_script.strip(),
                 outputs_body.get("found") == outputs_script.get("found")))
    else:
        ok("PARITY-{}".format(name.upper()), "byte-equal stdout and equal found= against {}".format(
            meta["detect_script"]))
    shutil.rmtree(d, ignore_errors=True)

# NPM EXCLUSION
if not inlined.get("npm"):
    fail("NPM-EXCLUSION",
         "not yet inlined — jobs.sca.steps[id=npm] still delegates to scripts/detect-npm.sh, "
         "cannot measure the inlined body's node_modules exclusion")
else:
    d = scratch_repo()
    for f in NPM_EXCLUSION_FIXTURES:
        write(d, f)
    git_commit_all(d)
    rc_body, out_body, outputs_body = run_body(str(steps["npm"].get("run") or ""), d)
    if "FOUND 1" not in out_body:
        fail("NPM-EXCLUSION", "expected FOUND 1 (node_modules paths excluded), got stdout={!r}".format(out_body))
    else:
        ok("NPM-EXCLUSION", "FOUND 1 — node_modules lockfiles correctly excluded")
    shutil.rmtree(d, ignore_errors=True)

# ── A4 PATHSPEC (independent of the YAML) ───────────────────────────────────
# Corrected five-item pathspec — see header note. Measures root, nested,
# Dockerfile.dev, app.dockerfile forms and excludes a docs/ decoy.
A4_PATHSPEC = ["Dockerfile", "*/Dockerfile", "Dockerfile.*", "*/Dockerfile.*", "*.dockerfile"]
A4_NAIVE_PATHSPEC = ["*Dockerfile", "*Dockerfile.*", "*.dockerfile"]
A4_EXPECTED = sorted(["Dockerfile", "svc/Dockerfile", "Dockerfile.dev", "app.dockerfile"])

d = scratch_repo()
write(d, "Dockerfile")
write(d, "svc/Dockerfile")
write(d, "Dockerfile.dev")
write(d, "app.dockerfile")
write(d, "docs/notes-Dockerfile.md")
git_commit_all(d)

proc = subprocess.run(["git", "ls-files", "--"] + A4_PATHSPEC, cwd=d, capture_output=True, text=True, check=True)
measured = sorted(p for p in proc.stdout.splitlines() if p)
print("A4 measured path set (corrected pathspec {!r}): {!r}".format(A4_PATHSPEC, measured))

proc_naive = subprocess.run(["git", "ls-files", "--"] + A4_NAIVE_PATHSPEC, cwd=d, capture_output=True, text=True, check=True)
measured_naive = sorted(p for p in proc_naive.stdout.splitlines() if p)
print("A4 INFORMATIONAL: naive 3-item pathspec {!r} measures {!r} (includes the decoy — "
      "do not use this form)".format(A4_NAIVE_PATHSPEC, measured_naive))

if measured != A4_EXPECTED:
    fail("A4-PATHSPEC", "corrected pathspec {!r} yielded {!r}, expected exactly {!r}".format(
        A4_PATHSPEC, measured, A4_EXPECTED))
else:
    ok("A4-PATHSPEC", "corrected pathspec matches exactly the four expected paths, decoy excluded")

# dirname derivation for build-context (plan 03 uses this for root Dockerfiles)
first_line = measured[0] if measured else ""
# Root Dockerfile always sorts alphabetically among the set; pick it explicitly.
root_candidates = [p for p in measured if p == "Dockerfile"]
if root_candidates:
    dn = os.path.dirname(root_candidates[0]) or "."
    if dn != ".":
        fail("A4-DIRNAME", "dirname of a root Dockerfile path is {!r}, expected '.'".format(dn))
    else:
        ok("A4-DIRNAME", "dirname of a root Dockerfile path is '.' as plan 03's build-context derivation expects")
else:
    fail("A4-DIRNAME", "no root-level Dockerfile in the measured set to derive dirname from")

shutil.rmtree(d, ignore_errors=True)

CHECK_LABEL = "check-detector-parity"

if failures:
    for line in failures:
        print(line)
    print("{}: PASSED {} / FAILED {}".format(CHECK_LABEL, passed, len(failures)))
    sys.exit(1)

print("{}: PASSED {} / FAILED 0".format(CHECK_LABEL, passed))
sys.exit(0)
PY

exit "$rc"
