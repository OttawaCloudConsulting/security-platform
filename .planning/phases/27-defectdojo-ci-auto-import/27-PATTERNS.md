# Phase 27: DefectDojo CI Auto-Import - Pattern Map

**Mapped:** 2026-09-25
**Files analyzed:** 11 (plus 1 do-not-change constraint)
**Analogs found:** 11 / 11. One file, the proof workflow, has only a partial analog.

Paths prefixed `sp/` are in the local clone `repos/security-platform/`. All other paths are in this documentation repo.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `sp/.github/workflows/security.yml` (MODIFY: secret decl, `closed` skip on 5 scan jobs, `defectdojo-import` + `defectdojo-cleanup` jobs) | config / workflow (callee) | request-response (HTTP to DefectDojo) + batch (artifact loop) | same file: `sast` job upload+verify pair (L96-215), `workflow_call.inputs` (L19-27), env chain (L41-47), container detect SKIP idiom (L934-946), pip-audit numbered loop (L670-718) | exact (self) |
| `sp/.github/workflows/pr-security.yml` (MODIFY: `types:` + `secrets:`) | config / caller | event-driven | same file (L1-82) | exact (self) |
| `sp/.github/workflows/scheduled-security.yml` (NEW) | config / caller | event-driven (schedule) | `sp/.github/workflows/pr-security.yml` | role-match |
| `sp/.github/workflows/defectdojo-import-proof.yml` (NEW) | test workflow | batch | `pr-security.yml` (the `uses:` job) + `security.yml` gitleaks install step (L1094-1102) + checkout pin (L76) | partial: no existing workflow has `workflow_dispatch`, `paths:` or `needs:` |
| `sp/scripts/check-workflow-uploads.sh` (EXTEND) | test / static gate | batch (YAML parse) | same file: JOB-SHAPE (L299-312), SHA-PIN (L184-202), DOCS tuple (L112-114) | exact (self) |
| `sp/scripts/defectdojo-live-smoke.sh` (EXTEND: optional post-hook) | test / live harness | request-response | same file: final `print_summary` (L744), `print_summary` (L175-199), CA extraction (L586-599) | exact (self) |
| `sp/scripts/defectdojo-import-proof.sh` (NEW) | test / live harness | request-response + transform (YAML step extraction) | `sp/scripts/defectdojo-live-smoke.sh` (helpers, creds, curl `--cacert`) + `sp/scripts/check-detector-parity.sh` (`find_step`, `run_body`, NO-SHELL-KEY) | role-match (composite) |
| `scripts/check-adoption-guide.sh` (EXTEND) | test / static gate | batch | same file: DERIVE-CONTEXTS (L86-119) | exact (self) |
| `docs/adr/adr024-<slug>.md` (NEW) | doc / ADR | n/a | `docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md` | exact |
| `docs/adr/README.md` (MODIFY: one row) | doc / index | n/a | same file, L33 row format | exact |
| `docs/adoption-guide.md` (MODIFY: "Enable DefectDojo import" section) | doc / guide | n/a | same file §5 Mode B caller fence (L158-216), §7 `gh variable set` idiom (L296-304), §10 SKIP text block (L491-503), §13 cross-refs (L655-678) | exact (self) |
| `sp/scripts/set-required-checks.sh` | **DO NOT CHANGE** | — | CONTEXTS L173-179 and L203-208 stay at the five scan contexts (D-03) | constraint |

---

## Pattern Assignments

### `sp/.github/workflows/security.yml` (callee, request-response + batch)

**Analog:** the file itself. Keep the heavy WHY-comment style: every new step needs a comment block above it, as at L108-130 and L161-171.

**A. Declare the optional secret as a sibling of `inputs:`** (existing block L19-27):
```yaml
on:
  workflow_call:
    inputs:
      gate_mode:
        description: >-
          "blocking" or "report-only". Omit to fall back to the caller repo's
          GATE_MODE variable, then to "report-only" (D-03).
        required: false
        type: string
```
Add `secrets: DEFECTDOJO_API_TOKEN: { description: ..., required: false }` under `workflow_call:`. Also update the header comment (L10-15). It says "exactly ONE per-repo substitution point across the whole bundle, `gate_mode`", which is no longer true once the `DEFECTDOJO_*` vars exist. Reword it; do not leave it stale.

**B. The `vars` resolution note to reuse** (L41-47). This is the justification for reading `vars.DEFECTDOJO_*` directly in the callee without a `with:` pass:
```yaml
# Workflow-level env is the only scope that sees both `inputs` and `vars` at
# once. Inside a called workflow, `vars` resolves to the CALLER repository,
# ...
env:
  GATE_MODE: ${{ inputs.gate_mode || vars.GATE_MODE || 'report-only' }}
```
The `DD_PRODUCT` fallback uses the same `||` chain, placed in step-level `env:`: `${{ vars.DEFECTDOJO_PRODUCT || github.repository }}`. `DD_PRODUCT_TYPE` does the same with `|| 'CI'`.

**C. Job header shape** (L56-59; each scan job is `name:` + `runs-on:` + `steps:`). Add a job-level `if: github.event.action != 'closed'` to each of `sast`, `iac`, `sca`, `container` and `secrets`, directly under `name:`. Do not change the ids or the `name:` values, because `check-workflow-uploads.sh` FROZEN_JOB_NAMES and the ordered list depend on them.

**D. Upload + tolerated side-channel + red verify pair.** This is the core pattern for the import step and its verify step. Tolerated upload (L96-100):
```yaml
      - name: Upload Semgrep SARIF
        id: sarif-semgrep
        if: always()                     # scanners exit non-zero by design (D-04)
        continue-on-error: true          # ADR-001: upload failures must not block
```
Red verify step (L204-215):
```yaml
      - name: Verify SAST artifact upload landed
        if: always() && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'
        run: |
          if [ "${{ steps.artifact-sast.outcome }}" != "success" ]; then
            echo "upload outcome=${{ steps.artifact-sast.outcome }} — the artifact did not land."
            echo "CICD-03 retains nothing for this job; a future DefectDojo import has no input."
            exit 1
          fi
```
Apply it to the new jobs as follows:
- The import step gets `id:` and `continue-on-error: true` with an ADR-001 carve-out comment.
- The verify step has **no** `continue-on-error`. It reads `steps.<import-id>.outcome` and the per-file results JSON, and it `exit 1`s unless every attempted file returned 201 with a `test_id`.
- **Do NOT copy the `head.repo.full_name` guard onto the new jobs.** It is false on `schedule` (RESEARCH Pitfall 3). Guard on `steps.gate.outputs.enabled == 'true'` instead (RESEARCH Pattern 1).

**E. SKIP-honesty idiom for absent inputs** (container detect step, L937-946):
```bash
          if [ "${count:-0}" -eq 0 ]; then
            echo "SKIP: no Dockerfile found — container sub-scan not applicable to this repository"
            echo "found=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          ...
          { echo "found=true"; echo "path=${first}"; } >> "$GITHUB_OUTPUT"
```
Reuse the same wording shape (`SKIP: <file> not in artifacts — <reason>`) for absent report files. The gate step writes `enabled=true|false` to `$GITHUB_OUTPUT` in the same way.

**F. Inline python3 heredoc idiom** (pip-audit verify, L692-718). Keep the quoted `'PY'` delimiter, `sys.argv` or env input, per-item `print` lines and `sys.exit(1)` on failure:
```yaml
        run: |
          python3 - pip-audit-*.json <<'PY'
          import json
          import sys

          for path in sys.argv[1:]:
              with open(path) as handle:
                  data = json.load(handle)
              if "dependencies" not in data:
                  print("pip-audit report has no dependencies key: {}".format(path))
                  sys.exit(1)
          PY
```
The existing code uses `.format()`, not f-strings. Match that style.

**G. Numbered report files** (pip-audit loop, L674-685, and the upload `path:` globs, L843-848). `npm-audit-N.json` and `pip-audit-N.json` are numbered per input, so the import table must glob them (`npm-audit-*.json`) and derive the test title from `N`. See RESEARCH OQ3 for the title-drift caveat.

**H. SHA-pinned action lines** (L76, L176):
```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
```
The new download step is `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c  # v8.0.1` with `pattern: '*-results'`, `merge-multiple: true` and `path: dd-reports` (RESEARCH Pattern 5).

**I. Injection note to update** (L916-924). The comment enumerates "the only context interpolations in any run: block". The new import and cleanup step bodies must add **none**, so the note stays true for them. The new verify step's `${{ steps.<id>.outcome }}` falls into the existing "GitHub-generated step outcomes" class. Update the note to say that.

---

### `sp/.github/workflows/pr-security.yml` (caller, event-driven)

**Analog:** the file itself (81 lines, read in full).

**Trigger to change** (L24-25):
```yaml
on:
  pull_request: {}
```
Change it to `pull_request: { types: [opened, synchronize, reopened, closed] }`. All three defaults must be restated (RESEARCH Pitfall 2). Add a WHY-comment in the style of L1-20.

**Frozen job and permission block to keep byte-identical** (L34-60): `security:`, `name: security`, the `permissions:` block with `contents: read`, `security-events: write` and `actions: read`, and `uses: ./.github/workflows/security.yml`.

**Add after `uses:`**: `secrets: { DEFECTDOJO_API_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }} }` with a comment saying never `inherit` (D-12). The existing "No `with:` block, deliberately" comment (L61-81) must stay accurate. It is about `with:`, not `secrets:`, but add a sentence explaining that `vars.DEFECTDOJO_*` are also not passed, because the callee reads the caller's `vars` directly.

---

### `sp/.github/workflows/scheduled-security.yml` (NEW caller, schedule)

**Analog:** `pr-security.yml`. Copy its structure verbatim: header comment block, `name:`, workflow-level `permissions: contents: read` floor (L27-31), job-level permissions with the three grants (L45-59), `uses:` line, and the new `secrets:` pass. Change only:
- `on:` → `schedule: [{ cron: '0 6 * * *', timezone: "America/Toronto" }]` + `workflow_dispatch: {}` (RESEARCH Pattern 6).
- Top-level `name:` (e.g. `Scheduled Security`).
- The job id: use `security`, or `scheduled`, and document the choice (RESEARCH OQ7). `check-adoption-guide.sh` reads only `pr-security.yml`, so this file does not affect DERIVE-CONTEXTS.
- The header ADOPTION comment: Mode B replaces the `uses:` line exactly as described in pr-security.yml L13-17.

---

### `sp/.github/workflows/defectdojo-import-proof.yml` (NEW test workflow, batch)

**Analog (partial):** no existing workflow in `sp/.github/workflows/` uses `workflow_dispatch`, `paths:`, `needs:` or a multi-job layout, so the shape comes from RESEARCH Pattern 7. Copy these parts from existing code:
- The `scans:` job's `permissions` + `uses: ./.github/workflows/security.yml` come from `pr-security.yml` L48-60. The job id must **not** be `security`.
- Checkout pin from `security.yml` L76.
- The Helm install follows the **download-verify-extract** precedent (`security.yml` L1094-1102):
```yaml
      # Download-then-verify-then-extract, never curl | sh — the SAST job's own
      # p/default ruleset (gha-curl-pipe-shell) flags the pipe pattern.
      - name: Install Gitleaks
        run: |
          curl -sSfL -o gitleaks.tar.gz \
            https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
          echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tar.gz" \
            | sha256sum -c -
          sudo tar xzf gitleaks.tar.gz -C /usr/local/bin gitleaks
```
  Helm v4.3.0 uses sha256 `86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb` and `--strip-components=1 linux-amd64/helm` (RESEARCH Standard Stack).
- The script invocation must be `bash scripts/defectdojo-import-proof.sh dd-reports`, never `./` and never `chmod +x`.
- Do not add a `shell:` key or a `defaults:` block. This file is not parsed by the detector-parity gate, but consistency matters.

---

### `sp/scripts/check-workflow-uploads.sh` (EXTEND static gate)

**Analog:** the file itself (326 lines, read in full).

**Constants to reuse** (L63-69, FROZEN_JOB_NAMES). Add a parallel `SCAN_JOB_IDS = ["sast", "iac", "sca", "container", "secrets"]` and `SIDE_CHANNEL_JOB_IDS = ["defectdojo-import", "defectdojo-cleanup"]`.

**JOB-SHAPE to rewrite deliberately** (L299-312). It fails as soon as a job is added:
```python
callee_jobs = callee.get("jobs") or {}
if len(callee_jobs) != 5:
    fail("JOB-SHAPE", ...)
for jid, body in callee_jobs.items():
    if isinstance(body, dict) and "needs" in body:
        fail("JOB-SHAPE", "jobs.{} declares needs: — the scan jobs must stay fully parallel".format(jid))
observed_names = [(body or {}).get("name") for body in callee_jobs.values()]
if observed_names != FROZEN_JOB_NAMES:
```
Change it to:
- Scan jobs (by id) exist, have no `needs:`, and have names in frozen order.
- Side-channel jobs are allow-listed and may carry `needs:`.
- Any other job still fails.
- Optionally assert that no side-channel job name appears in `set-required-checks.sh`.

**SHA-PIN extension** (L184-202 iterates `DOCS`, defined at L112-114):
```python
caller = load(CALLER)
callee = load(CALLEE)
DOCS = ((CALLER, caller), (CALLEE, callee))
```
Extend `DOCS`, or glob `.github/workflows/*.yml`, so that `scheduled-security.yml` and `defectdojo-import-proof.yml` are pin-checked (RESEARCH Pitfall 13). PERMISSIONS-FORBIDDEN (L162-182) also iterates `DOCS`, so the new files get that check too.

**Scope note:** UPLOAD-VERIFY-PAIRING (L272-288) only fires on `upload-sarif` and `upload-artifact` steps. The import step's curl-then-verify pairing is **not** covered. If the planner wants that invariant, it needs a new check (for example IMPORT-VERIFY-PAIRING: the import step id is read as `steps.<id>.outcome` by a later step), plus a `CHECK_COUNT` bump (L314). It will not pass by accident.

**Conventions to keep:** exit 0/1/2 (L18-25), the PyYAML preflight exit 2 with no regex fallback (L38-42), the quoted `'PY'` heredoc (L46-50), and "report EVERY failure" via the `fail()` list (L100-104). Also update the header echo (L44), which names only two files.

---

### `sp/scripts/defectdojo-live-smoke.sh` (EXTEND: optional post-hook)

**Analog:** the file itself.

**Critical placement fact.** `print_summary` (L175-199) calls `exit 1` or `exit 0` itself:
```bash
  if [ "${#FAILURES[@]}" -gt 0 ]; then
    ...
    exit 1
  elif [ "$CHECKS_PASSED" -eq 0 ]; then
    ...
    exit 0
  else
    echo "ALL PASS - ${CHECKS_PASSED} live check(s) executed and passed; ..."
    exit 0
  fi
```
A hook placed "after print_summary reports ALL PASS" would never run. Insert it **before the final `print_summary` at L744** and guard it on `[ "${#FAILURES[@]}" -eq 0 ] && [ -n "${DD_SMOKE_POST_HOOK:-}" ]`. It runs while the EXIT trap (L121) still owns the port-forward and the kind cluster. Record the hook's exit code through the `fail`/`pass` helpers (L157-164). Do not use a bare call under `set -e`, because the summary must still print. Nothing may change when the variable is unset.

**Values the hook needs to be exported** (from L85-86, L102-104, L306, L596):
```bash
readonly PF_PORT="18443"
readonly BASE_URL="https://${SMOKE_HOST}:${PF_PORT}"
KIND_CONTEXT="kind-${KIND_CLUSTER}"
( umask 077; printf '%s' "$DD_ADMIN_PW" > "$OUT/admin-pw" )
base64 -d < "$OUT/ca.crt.b64" > "$OUT/ca.crt"
```
The hook needs `BASE_URL`, `$OUT/ca.crt`, `$OUT/admin-pw` and `KIND_CONTEXT`. Pass the file paths, never the password itself.

**Warning (26-REVIEW):** the five open Phase 26 review warnings are out of scope unless the harness cannot run without a fix (CONTEXT domain).

---

### `sp/scripts/defectdojo-import-proof.sh` (NEW live harness)

**Analog 1: `sp/scripts/defectdojo-live-smoke.sh`**, for the harness skeleton. Copy these verbatim:
- The header style (L4-59): WHY-EXISTS, exit codes 0/1/2, and "Never set the executable bit ... Invoke as: bash scripts/...".
- `REPO_ROOT` cd (L60-61).
- `require_success` / `pass` / `fail` / `print_summary` (L139-199), including the "NOTHING RAN is not a pass" branch.
- The hard-tier preflight loop (L227-232):
```bash
for bin in curl jq yq helm docker openssl; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 2
  fi
done
```
- Credential files: `( umask 077; printf '%s' "$X" > "$OUT/file" )` (L302-306). Secrets never go on argv, and `set -x` is never used.
- The verified-TLS curl form with an asserted `ssl_verify_result` (L624-638):
```bash
tls_out="$(curl -sS --resolve "${SMOKE_HOST}:${PF_PORT}:127.0.0.1" --cacert "$OUT/ca.crt" -o /dev/null -w '%{http_code} %{ssl_verify_result}' "${BASE_URL}/login" 2>"$OUT/tls.err")" || tls_rc=$?
```
  In the proof, switch from `--resolve` to the `/etc/hosts` line (RESEARCH Pattern 7 step 2), so the committed step body has no harness-only branch.
- `gen_secret` (L214-222) is **alphanumeric only**. For the `ci-importer` user password, append a fixed suffix that covers every required character class, keeping the total within 9-48 chars (RESEARCH Pitfall 10), or `POST /users/` returns 400.

**Analog 2: `sp/scripts/check-detector-parity.sh`**, for extract-and-run of the committed step body. Step lookup by job and step id (L93-100):
```python
def find_step(job_id, step_id):
    job = jobs.get(job_id)
    if not isinstance(job, dict):
        return None, "job {!r} not found".format(job_id)
    for step in job.get("steps") or []:
        if isinstance(step, dict) and step.get("id") == step_id:
            return step, None
    return None, "step id {!r} not found in job {!r}".format(step_id, job_id)
```
Executing the body under the runner default (L192-214):
```python
def run_body(body, cwd, extra_env=None):
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
```
Then add the new assertion: fail if `"${{"` appears in an extracted import or cleanup body (RESEARCH Pattern 7 step 4). Supply `DD_URL`, `DD_TOKEN`, `DD_PRODUCT`, `DD_PRODUCT_TYPE`, the CA var, `GITHUB_EVENT_NAME`, `GITHUB_HEAD_REF`, `GITHUB_REF_NAME`, `GITHUB_SHA`, `GITHUB_RUN_ID`, `GITHUB_SERVER_URL`, `GITHUB_REPOSITORY`, and `HEAD_REF`/`DEFAULT_BRANCH` for cleanup, through `extra_env`.

**Assertion list:** RESEARCH "Phase Requirements to Test Map" rows 5-10 and Pitfall 6 (a)/(b)/(c). The token must be staff and not superuser, and no `-k` may appear anywhere in the proof path.

---

### `scripts/check-adoption-guide.sh` (EXTEND, this repo)

**Analog:** the file itself (274 lines, read in full).

**Derivation to change** (L89-102). It currently takes every named callee job:
```python
callee_jobs = callee.get("jobs") or {}
job_names = [body.get("name") for body in callee_jobs.values() if isinstance(body, dict)]
job_names = [n for n in job_names if n]
...
if len(job_names) != 5:
    fail("DERIVE-CONTEXTS", "expected exactly 5 job name: values in {}, found {}: {!r}".format(
```
Filter it by the five scan job **ids** (`sast iac sca container secrets`, in that order) and keep the `!= 5` assertion. Leave the caller check at `!= 1` (L100-102), because pr-security.yml keeps one job. Do not rely on unnamed side-channel jobs slipping past the `if n` filter (RESEARCH Pitfall 1 warning sign).

**Gate traps the new guide section must respect:**
- **SIXTH-CONTEXT** (L153-162): no literal `security / DefectDojo Import` or `security / DefectDojo Cleanup` anywhere in the guide. Say "the import job" in prose.
- **REUSABLE-WORKFLOW-REF** (L171-182): the allowed regex is `security\.yml@(v1|v1\.0\.0)$` only. If the section writes the new `v1.x` tag as a `uses:` ref, the gate goes red. Either reference only `@v1` or extend the regex deliberately.
- **RAW-GITHUBUSERCONTENT-PIN** (L185-192): the `scheduled-security.yml` fetch URL must contain `/v1/`.
- **BANNED-PATTERNS** (L198-233): no `|| true` in the guide outside a fence that has an "anti-pattern" or "DO NOT" label within 3 lines above it. Do not paste smoke-script cleanup lines.
- **NO-FIXTURES-DIR** (L236-246) and **MARKDOWNLINT** (L249-260) also apply to the new section.

---

### `docs/adr/adr024-<slug>.md` (NEW ADR)

**Analog:** `docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md` (215 lines).

**Header block** (L1-14):
```markdown
# ADR-023: DefectDojo Chart Base, cert-manager Issuer Guard and Pinned Version

**Status:** Accepted
**Date:** 2026-09-24
**Addresses:** DDOJO-01 — a public Helm chart deploys DefectDojo with external ingress and
cert-manager-issued TLS

This record lives in this documentation repository. ... Every measured value below is
quoted from a Phase 26 plan summary, from a file in that phase's `evidence/` directory, or from a
statement 26-RESEARCH marks `[VERIFIED]`; each is attributed where it appears. ... No homelab
address, hostname, node name, kube context name or issuer name appears here.
```
**Sections, in order:** `## Context` (bold-lead bullets), `## Decision`, `## Consequences`, `## What was NOT verified`. Lines wrap at about 110 columns. ADR-024 must also record these items:
- Pitfall 4: the verify steps skip on `schedule`.
- Pitfall 8: the closed-PR window with skipped contexts.
- OQ3: npm title drift.
- OQ5: the Phase 29 side effect.
- The dedup hand-forward to Phase 28 (`enable_deduplication` and `deduplication_on_engagement`).
- That staff is an instance-wide bypass.
- The deferral of the TFLint native parser.

The ADR is append-only. Do not edit ADR-001, ADR-017, ADR-018 or ADR-023.

### `docs/adr/README.md` (MODIFY)

**Row format** (L33):
```markdown
| [ADR-023](adr023-defectdojo-chart-base-tls-guard-and-version-pin.md) | DefectDojo Chart Base, cert-manager Issuer Guard and Pinned Version | 2026-09-24 | Accepted |
```
Append the ADR-024 row directly below it.

---

### `docs/adoption-guide.md` (MODIFY: new "Enable DefectDojo import" section)

**Analog:** the file itself.

**Where it goes:** the guide has numbered `##` sections, 1-13 (L19-655). Insert the new numbered section before `## 12. Troubleshooting` (L576), then renumber the later sections, or append it as a new number before §13. Add ADR-024 to the §13 cross-references (L655-666) in the same bullet format:
```markdown
- [ADR-018](adr/adr018-workflow-packaging-canonical-host-and-versioning.md) — this phase's
  packaging, canonical-host and versioning decisions.
```

**Variable-setting idiom** (§7 L300-304). Commands go in a `bash` fence, and expected or observed notes go on `##` comment lines:
```bash
gh variable set GATE_MODE --body blocking -R OWNER/REPO
  ## Never executed against any pilot repository in this guide's own proving runs — ...
```
Use it for `gh variable set DEFECTDOJO_URL ...`, `gh secret set DEFECTDOJO_API_TOKEN ...` and the optional `DEFECTDOJO_PRODUCT`, `DEFECTDOJO_PRODUCT_TYPE`, `DEFECTDOJO_INSECURE` and CA vars. Be honest about what was and was not executed, in the same way.

**Caller-block idiom** (§5 L162-205): show a full fenced `yaml` caller with WHY-comments. Show the updated `pr-security.yml` (`types:` + `secrets:`) for **both** modes (RESEARCH Pitfall 13a), plus the optional `scheduled-security.yml`. For Mode A, add the fetch line in the §4 L115-121 style:
```bash
curl -fsSL -o .github/workflows/pr-security.yml \
  https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/.github/workflows/pr-security.yml
```

**SKIP text-block idiom** (§10 L496-501): list the import and cleanup SKIP log lines in a `text` fence.

**Content the section must include:** the token identity (a dedicated `is_staff` user that is not a superuser, and staff is an instance-wide bypass), the reachability note (D-17), the TLS default and the per-run `DEFECTDOJO_INSECURE` warning, Product Type drift causing a 400 (Pitfall 5), and scheduled workflows auto-disabling after 60 days (Pitfall 12).

---

## Shared Patterns

### ADR-001 side-channel carve-out plus red verify
**Source:** `sp/.github/workflows/security.yml` L96-100 and L204-215. The gate that enforces it for uploads is `sp/scripts/check-workflow-uploads.sh` L272-288.
**Apply to:** the import step and the cleanup delete step. Each gets `continue-on-error: true` and an `id:`. A later step with no `continue-on-error` reads `steps.<id>.outcome` and `exit 1`s.

### Injection and secret hygiene
**Source:** `security.yml` L916-924 (the interpolation inventory) and the smoke L290-306 (never on argv, umask 077, no `set -x`).
**Apply to:** every new `run:` body that talks to DefectDojo.
- Values arrive through step-level `env:` only.
- Extracted bodies contain zero `${{`.
- The token goes into a header file (`-H @file`).
- `--form-string` is used for every non-file field.
- There is no job-level `env:` holding the secret.

### No `shell:` key and no `defaults:` block anywhere in security.yml
**Source:** `sp/scripts/check-detector-parity.sh` L130-147:
```python
if doc.get("defaults"):
    fail("NO-SHELL-KEY", "top-level defaults: block exists — bash -e assumption invalid")
...
        if isinstance(step, dict) and step.get("shell"):
            fail("NO-SHELL-KEY", "jobs.{}.steps[{}] declares shell: {!r}".format(
```
**Apply to:** the new import and cleanup jobs. If any step declares `shell: bash`, the existing parity gate turns red, and the proof harness's `bash -e` extraction premise breaks.

### Exit-code contract for gates and harnesses
**Source:** `check-workflow-uploads.sh` L18-25 and smoke L54-59. Exit 0 is pass, 1 is an assertion failure, 2 is preflight or infrastructure. There are no silent fallbacks and no `|| true` on an assertion. `|| true` is allowed only for cleanup hygiene or a discovery pipeline, with a comment saying so (smoke L117-121, security.yml L931-932).
**Apply to:** `defectdojo-import-proof.sh`, both extended gates, and the verify steps.

### SHA-pinned actions with version comments
**Source:** `security.yml` L76, L176; ADR-004.
**Apply to:** `download-artifact` in security.yml, and checkout and download-artifact in the proof workflow. Binaries use download + `sha256sum -c` + extract, never `curl | sh` (L1094-1102).

### WHY-comments on consumer-copied files
**Source:** `pr-security.yml` L1-20 and L35-81; `security.yml` L108-130.
**Apply to:** security.yml, pr-security.yml and scheduled-security.yml.

### Frozen required contexts
**Source:** `sp/scripts/set-required-checks.sh` L203-208 (CONTEXTS list) and `check-workflow-uploads.sh` L63-69.
**Apply to:** every plan. The import and cleanup jobs never enter these lists.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `sp/.github/workflows/defectdojo-import-proof.yml` (overall shape) | test workflow | batch | Only two workflows exist, and neither uses `workflow_dispatch`, `pull_request.paths`, `needs:` or a `uses:` job plus `runs-on:` job pair. Use RESEARCH Pattern 7 for the skeleton. The individual steps have analogs, listed above. |
| DefectDojo API calls (reimport multipart, engagement GET/DELETE, token mint, user create) | — | request-response | No existing code calls DefectDojo API v2. The smoke only does HTML login plus CSRF. Use RESEARCH Pattern 5 (curl form) and the Code Examples delete guard. Take TLS and credential handling from the smoke. |

## Metadata

**Analog search scope:** `repos/security-platform/.github/workflows/`, `repos/security-platform/scripts/`, `scripts/`, `docs/adr/`, `docs/adoption-guide.md`
**Files scanned:** 12 (security.yml by targeted ranges; pr-security.yml, check-workflow-uploads.sh and check-adoption-guide.sh in full; check-detector-parity.sh L60-239; defectdojo-live-smoke.sh by targeted ranges; set-required-checks.sh by grep; ADR-023 header; ADR README; adoption-guide by sections; ADR-018 by grep)
**Pattern extraction date:** 2026-09-25
