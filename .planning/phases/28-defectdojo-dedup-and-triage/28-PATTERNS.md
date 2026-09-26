# Phase 28: DefectDojo Dedup and Triage - Pattern Map

**Mapped:** 2026-09-25
**Files analyzed:** 13 (8 in `repos/security-platform/`, 5 in this repository)
**Analogs found:** 12 / 13 (the triage runbook has no runbook analog; it copies README prose style)

Scope is fixed by CONTEXT.md D-01..D-23 (post-research D-20..D-23 narrow D-09/D-10/D-15). No `security.yml` change, no v1.x tag (RESEARCH Summary item 4; D-20). Line numbers below were read on 2026-09-25 from the local clone (`repos/security-platform`, HEAD `ba3683a`) and this repository.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `repos/security-platform/kubernetes/defectdojo/values.yaml` (modify) | config | transform (values → ConfigMap → env) | same file, lines 50-103 (restated keys with `# --` WHY-comments) | exact |
| `repos/security-platform/kubernetes/defectdojo/Chart.yaml` (modify, `version` bump) | config | n/a | same file (9 lines) | exact |
| `repos/security-platform/kubernetes/defectdojo/README.md` (modify) | doc | n/a | same file: Requirements table L46-54, Validating L281-309, Values table L311-335, Limitations L337-350 | exact |
| `repos/security-platform/kubernetes/defectdojo/TRIAGE.md` (NEW) | doc (runbook) | n/a | `kubernetes/defectdojo/README.md` prose/table style | style-only (no runbook exists) |
| `repos/security-platform/scripts/defectdojo-configure.sh` (NEW) | utility (operator bootstrap) | request-response (GET-compare-PATCH, idempotent) | Python client in `security.yml` `dd-delete` step L1712-1890 + bash shell of `scripts/defectdojo-import-proof.sh` L1-128 | role-match (composite) |
| `repos/security-platform/scripts/check-defectdojo-chart.sh` (modify) | test (offline gate) | batch assertion over `helm template` | same file, check 18 UWSGI-FOOTPRINT L423-442 | exact |
| `repos/security-platform/scripts/defectdojo-import-proof.sh` (modify) | test (live kind proof) | request-response + assertion | same file: P-USER L698-728, P-RUN1 L764-802, read-side Python L804-870, P-CLEANUP L1289-1341 | exact |
| `repos/security-platform/.github/workflows/defectdojo-import-proof.yml` (modify) | config (CI) | event-driven (path filter) | same file L29-51 | exact |
| `docs/adr/adr026-<slug>.md` (NEW) | doc (ADR) | n/a | `docs/adr/adr025-defectdojo-import-https-only.md` | exact |
| `docs/adr/README.md` (modify) | doc (index) | n/a | same file L35 | exact |
| `docs/adoption-guide.md` (modify) | doc | n/a | same file §12 L599-818 | exact |
| `scripts/check-adoption-guide.sh` (modify) | test (offline gate) | batch assertion | same file DEFECTDOJO-SECTION L263-296 | exact |
| `.planning/REQUIREMENTS.md` (modify) | doc (tracking) | n/a | same file L22-23 (`[x]` DDOJO-01/02) and L52-53 (Complete rows) | exact |

## Pattern Assignments

### `kubernetes/defectdojo/values.yaml` (config)

**Analog:** same file. Every restated key carries a helm-docs `# --` comment with its WHY and decision ID. Copy this style (lines 98-103):

```yaml
  valkey:
    persistence:
      # -- Valkey is only the Celery broker; queued tasks are transient. The
      # upstream valkey 0.25.8 subchart defaults this to `true` with an 8Gi PVC,
      # so it is turned off here (ephemeral Valkey, D-08).
      enabled: false
```

**Where it goes:** a new `extraConfigs:` block directly under `defectdojo:` (sibling of `django:` / `valkey:`, before the `# NOTE: deliberately NOT restated` block at L105-117). The upstream key is the subchart's top-level `extraConfigs` (RESEARCH Pattern 2). Exactly two keys (D-20). The RESEARCH "Code Examples → Chart defaults" block (RESEARCH L344-359) is the target content; cite ADR-026 and D-20 in the comments.

**Constraints:**
- Values are STRINGS. `DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"` must be quoted (ConfigMap `data` is string-only).
- The header comment L1-18 says "only the keys whose upstream default is wrong (or must not silently drift) ... are restated (D-04)". Add one sentence there that D-20 (ADR-026) deliberately adds the dedup guards.
- README L342 already tells consumers to put `defectdojo.extraConfigs.DD_CSRF_TRUSTED_ORIGINS` in an overlay. Helm map-merges `extraConfigs`, so an overlay adding that key keeps the two new defaults. Say so in the comment.
- Gate check 20 PLACEHOLDER-ONLY (`check-defectdojo-chart.sh` L466) greps `values.yaml` for `ottawacloudconsulting|letsencrypt|occ-|homelab` (case-insensitive). No new comment may contain those words (for example, do not write "homelab install is Phase 29").
- Do NOT add `DD_HASHCODE_FIELDS_PER_SCANNER` (D-20, RESEARCH Anti-Patterns).

---

### `kubernetes/defectdojo/Chart.yaml` (config)

**Analog:** same file (all 9 lines):

```yaml
apiVersion: v2
name: defectdojo
version: 0.1.0
appVersion: "3.3.200"
```

Only `version` moves (for example 0.1.0 → 0.2.0: new default values, no app change). `appVersion` and the dependency version stay: the IMAGE-PIN check (gate L343-376) fails if the four pin points diverge. CONTEXT "Claude's Discretion": a chart-only change follows the chart's own versioning, and no security-platform git tag is needed.

---

### `kubernetes/defectdojo/README.md` (doc)

**Analog:** same file.

**D-19 rows** (L50-54). Current text:

```markdown
| DDOJO-01 | Public Helm chart deploys DefectDojo with external ingress and cert-manager-issued TLS | Complete (Phase 26) |
| DDOJO-02 | CI scan jobs import SARIF/JSON findings into DefectDojo after each run | Planned (Phase 27) |
| DDOJO-03 | Deduplication rules collapse repeated findings across scans and tools | Planned (Phase 28) |
| DDOJO-04 | Triage workflow for reviewing and dispositioning findings | Planned (Phase 28) |
```

Change L52-53 to `Complete (Phase 28)`, following L50. **Stale neighbour:** L51 (DDOJO-02) still says `Planned (Phase 27)` while `.planning/REQUIREMENTS.md` L22/L53 mark DDOJO-02 Complete. It is not in D-19's scope, so the planner decides whether to fix it and must record the decision either way.

**Architecture tree** (L11-18): add `TRIAGE.md` to the tree, in the same comment style:
```text
├── values.yaml            # the consumer value surface, all under the `defectdojo` key
```

**Validating an install** (L283-296): the literal `20 invariants` / `PASS - 20 checks, 0 failures` at L285 must move with the gate count (see gate section). Add a bullet naming the dedup-guard checks, in the style of L287-294.

**Values table** (L315-328): add rows for the two `extraConfigs` keys in the style of:
```markdown
| `defectdojo.valkey.persistence.enabled` | `false` | Valkey is only the Celery broker. Upstream valkey 0.25.8 defaults to an 8Gi PVC. |
```

**New content (RESEARCH "Recommended file layout")**: a "Dedup and triage" section with the mandatory post-install bootstrap step (`bash scripts/defectdojo-configure.sh`, superuser token, Pitfalls 1-2), placed after Install L198-220. Also the D-08 recompute note (RESEARCH "Hash recompute" block L389-399: `kubectl -n <ns> exec deploy/<release-fullname>-django -c uwsgi -- python manage.py dedupe ...`). A pointer to `TRIAGE.md` and ADR-026 goes into the "decisions behind this chart" bullet L350:
```markdown
- **The decisions behind this chart** are recorded in ADR-023 in the `security_solution` documentation repository: ...
```

---

### `kubernetes/defectdojo/TRIAGE.md` (NEW, runbook)

**Analog:** none as a runbook. Copy the prose conventions of `kubernetes/defectdojo/README.md`: a `#` title plus a short purpose paragraph (L1-5), `##` sections, pipe tables with a header separator `|---|---|---|` (L35-44), fenced `bash` blocks for commands (L200-207), `example.com`/`example.org` placeholders only, and bold lead-in bullets in the style of L339-349 (`- **Title.** Explanation.`).

Content comes from RESEARCH, not from code: Pattern 4 (the exact post-reimport tuples: FP/OOS become `is_mitigated=True`, RA unchanged), Pattern 5 (suppression), Pattern 6 + D-23 (the Under Review filter and API query at RESEARCH L262), Pattern 7 + D-22 (the RA API, the 90-day form default, expiry and reason mandatory by procedure), Pitfall 8 (line-shift noise), Caveat A (triage on `ci/<default>` only, a hard rule), Caveat B, D-13 (no sync with the GitHub Security tab), D-21 (SLA not configured). The disposition API shapes are at RESEARCH L377-387.

**Side effect:** `kubernetes/defectdojo/**` is in the proof workflow's `paths:` (proof yml L51), so every TRIAGE.md edit on a PR triggers the 15-30 min proof. Batch runbook edits.

---

### `scripts/defectdojo-configure.sh` (NEW, utility, request-response)

**Analog A (bash shell):** `scripts/defectdojo-import-proof.sh`.

Header and preamble (L1-2, L67-84): `set -euo pipefail`, a WHY-THIS-EXISTS block, "Never set the executable bit ... Invoke as: bash scripts/...", and three exit codes:
```bash
# Exit codes:
#   0  --extract-only: every static check passed; --hook: every proof
#      assertion passed
#   1  at least one check or proof assertion failed, or the proof is incomplete
#   2  preflight failure: a required binary, report file or hook variable is
#      missing

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
```

`usage` / `require_bins` (L115-128):
```bash
usage() {
  echo "usage: bash scripts/defectdojo-import-proof.sh <reports-dir> | --extract-only | --scheme-only | --hook" >&2
  exit 2
}

require_bins() {
  local bin
  for bin in "$@"; do
    if ! command -v "$bin" &>/dev/null; then
      echo "FATAL: required binary '${bin}' not found on PATH" >&2
      exit 2
    fi
  done
}
```

The env-var preflight loop from `mode_hook` (L629-646) is the shape for required inputs (URL, token-header file, optional CA file):
```bash
  for v in BASE_URL SMOKE_HOST PF_PORT KIND_CONTEXT ADMIN_USER DD_CA_FILE DD_ADMIN_PW_FILE DD_SMOKE_OUT DD_PROOF_REPORTS; do
    if [ -z "${!v:-}" ]; then
      echo "FATAL: --hook needs ${v} (exported by defectdojo-live-smoke.sh / the entry mode)" >&2
      exit 2
    fi
  done
```
Also copy `umask 077` (L650).

**Analog B (Python API client, the Phase 27 idiom):** `.github/workflows/security.yml`, `dd-delete` step body. Run it as `python3 - <<'PY'` with inputs through the environment only (L1712-1732):
```python
env = os.environ
url = env.get("DD_URL", "").rstrip("/")
...
tmpdir = tempfile.mkdtemp()
hdr_path = os.path.join(tmpdir, "auth-header")
ca_path = os.path.join(tmpdir, "ca.pem")
resp_path = os.path.join(tmpdir, "response.json")
```

The 0600 writer and failure type (L1735-1742):
```python
class Failed(Exception):
    pass


def write_private(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as handle:
        handle.write(text)
```

The request helper, pinned to https (L1757-1784):
```python
def api(tls_args, method, path, expect):
    cmd = ["curl", "-sS", "--proto", "=https", "--proto-redir", "=https", "-X", method, "-o", resp_path, "-w", "%{http_code}"] + tls_args
    cmd += ["-H", "@" + hdr_path, url + path]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          universal_newlines=True)
    code = (proc.stdout or "").strip() or "000"
    ...
    if code != expect:
        detail = body[:500] if body else (proc.stderr or "").strip()[:500]
        print("FAILED: {} {} http={} body={}".format(method, path, code, detail))
        raise Failed()
```

The https refusal is the first statement of `main()` (ADR-025 decision 1; L1795-1799):
```python
    # CR-01 / ADR-025: refuse a non-https URL before the TLS label, the token header and any request.
    if not url.lower().startswith("https://"):
        print("FAILED: DEFECTDOJO_URL must be https:// — refusing to send the API token over {!r}".format(
            url.split("://", 1)[0] if "://" in url else "(no scheme)"))
        raise Failed()
```

Cleanup in `finally` (L1880-1890):
```python
try:
    try:
        rc = main()
    except Failed:
        rc = 1
finally:
    for leftover in (hdr_path, ca_path, resp_path):
        if os.path.exists(leftover):
            os.remove(leftover)
    os.rmdir(tmpdir)
sys.exit(rc)
```

**Gaps the executor must fill (no analog line covers them):**
1. `api()` sends no body, and its `expect != "200"` branch returns None while its 200 branch requires a `results` list. `GET /api/v2/system_settings/` returns a `results` list (the RESEARCH L369 "results[0]"), which fits. The PATCH to `/api/v2/system_settings/<id>/` returns a single object, so it needs its own branch or helper. For the PATCH body, write the drift JSON with `write_private(body_path, json.dumps(drift))` and send it with `--data-binary @body_path -H 'Content-Type: application/json'`. That is the shape of `mint_token` (proof L364-367):
   ```bash
   jq -n --arg u "$user" --rawfile pw "$pwfile" '{username: $u, password: $pw}' > "$body"
   out="$(api_call "$resp" -X POST -H 'Content-Type: application/json' --data-binary "@${body}" \
     "${BASE_URL}/api/v2/api-token-auth/" 2>"${PROOF_DIR}/${label}-auth.err")" || rc=$?
   ```
   Add `body_path` to the `finally` leftovers.
2. **Token input:** read a token or a header file from a path in an env var, never argv (D-10). The proof builds `admin.hdr` (an `Authorization: Token ...` line) and **deletes `admin.token` right after** (proof L689-695):
   ```bash
   { printf 'Authorization: Token '; cat "$admin_tok"; printf '\n'; } > "$admin_hdr"
   rm -f "$admin_tok"
   ```
   So the script's interface should either accept a header file, or the proof must re-mint the admin token before calling it. Choose one explicitly.
3. **TLS inputs:** the proof talks to kind through `--cacert "$DD_CA_FILE"` plus a `CURL_HOME` curlrc `resolve` line (proof L672-675). The script must call plain `curl` (never `-q`/`--disable`, which would skip the curlrc) and must accept a CA file path (security.yml takes PEM text through `DD_CA_CERT` and writes `ca_path`; a file path is simpler for an operator script, so pick one). Never add `-k`. D-10 says TLS is verified with no insecure mode, so do not port the `DD_INSECURE` branch (L1812-1817).
4. **Desired state (D-10, D-21, D-22):** `enable_deduplication=true, delete_duplicates=false, false_positive_history=false, retroactive_false_positive_history=false, risk_acceptance_form_default_days=90`. Leave `enable_finding_sla` alone. Use read-compare-PATCH with drift only, re-GET and assert, and print a line starting `NO CHANGE` or `CHANGED:` (RESEARCH L366-374) so the proof's idempotency assertion can grep it. Use the id returned by GET, not a literal 1 (RESEARCH A5).

---

### `scripts/check-defectdojo-chart.sh` (test, offline gate)

**Analog:** same file, check 18 UWSGI-FOOTPRINT (L423-442). Select the ConfigMap by the key it carries, not by name. `extraConfigs` renders into the same main ConfigMap as `DD_UWSGI_NUM_OF_PROCESSES` (RESEARCH Pattern 2), so either reuse the `uwsgi_cm` selector or define a sibling selector keyed on the new key:
```bash
uwsgi_cm='select(.kind=="ConfigMap" and ((.data // {}) | has("DD_UWSGI_NUM_OF_PROCESSES")))'
if ! uwsgi_procs=$(render | yq "${uwsgi_cm} | .data.DD_UWSGI_NUM_OF_PROCESSES"); then
  fail "UWSGI-FOOTPRINT" "render or yq failed reading DD_UWSGI_NUM_OF_PROCESSES from the ConfigMap"
elif [ "$(unquote "$uwsgi_procs")" != "2" ]; then
  fail "UWSGI-FOOTPRINT" "expected DD_UWSGI_NUM_OF_PROCESSES == \"2\" in the rendered ConfigMap, got '${uwsgi_procs}' (empty means no ConfigMap carries the key)"
fi
```

Section header style (for example L423): `# ── 18. UWSGI-FOOTPRINT ───...` followed by a WHY comment block. New checks become 21 and 22 (for example `CASCADE-DELETE-OFF`, `DEDUP-ALGORITHM-MAP`), placed after check 20 (L461-471) and before `# ── Terminal summary` (L473).

**Count literal, 3 places plus 1 downstream (RESEARCH Pitfall 5):** L19 (`It asserts 20 offline invariants`), L96 (`asserting 20 offline invariants`), L474 (`CHECK_COUNT=20`), and README.md L285 (`20 invariants` / `PASS - 20 checks`). All four move in one commit.

**JSON assertion (RESEARCH Pitfall 4):** `jq` is already a preflight binary (L66) but is unused today. Pipe the rendered value to `jq -e` to check that it parses and that every value is in `{legacy, unique_id_from_tool, hash_code, unique_id_from_tool_or_hash_code}`, and that the 7 scan_type keys are exactly the security.yml TABLE set (the proof's `TABLE`, L873-882, lists the same scan types). **Measured locally (yq v4.53.6, synthetic file, not a helm render):** `yq '.data.KEY'` prints a JSON string value unwrapped in both single-quoted and `\"`-escaped YAML forms (`{"Trivy Scan": "hash_code"}`), so `unquote` + `jq -e` works. Re-verify against the real `helm template` output while implementing.

Also add a toggle half in the style of check 9 (L264-268), proving that a consumer override reaches the ConfigMap, if the planner wants to prove the value is not inert.

---

### `scripts/defectdojo-import-proof.sh` (test, live proof)

**Analog:** same file. Helpers to reuse unchanged:

- Tally (L322-348): `proof_pass ID DETAIL`, `proof_fail ID DETAIL`, `proof_abort ID DETAIL` (use it only when later assertions depend on the step), and `proof_finish`.
- `api_call OUTFILE ARGS...` (L353-357): a verified-TLS request that prints `"<http_code> <ssl_verify_result>"`:
  ```bash
  api_call() {
    local out="$1"
    shift
    curl -sS --cacert "$DD_CA_FILE" -o "$out" -w '%{http_code} %{ssl_verify_result}' "$@"
  }
  ```
- The admin-authenticated PATCH/POST shape is P-USER (L702-714). Use it for the `ci-importer` `user_contact_infos` PATCH to `deduplication_execution_mode=async_wait` (Pitfall 3) and for the finding dispositions and the RA POST:
  ```bash
  out="$(api_call "${PROOF_DIR}/user-create.json" -X POST -H "@${admin_hdr}" -H 'Content-Type: application/json' \
    --data-binary "@${user_body}" "${BASE_URL}/api/v2/users/" 2>"${PROOF_DIR}/user-create.err")" || rc=$?
  rm -f "$user_body"
  code="${out%% *}"
  ```
- `run_body LABEL BODYFILE NAME=VALUE...` (L391-407) runs the committed security.yml bodies (the single-source rule, T-27-01). Every Phase 28 import and delete must go through `$b_import` / `$b_delete` (L666-668) with the env list of P-RUN1 (L768-784) or P-CLEANUP. Set `DD_PRODUCT` to the fresh Phase 28 product (RESEARCH OQ4), `GITHUB_EVENT_NAME=schedule` with an empty head ref and `GITHUB_REF_NAME=main` for the default branch (the P-SCHEDULE pattern around L1183-1211), and `pull_request` + `GITHUB_HEAD_REF=<pr branch>` for the PR.
- Read-side assertions in Python (L808-870, tallied with `tally_assert_log` L419-435): heredoc `python3 - > "$assert_log" 2>&1 <<'PY' || py_rc=$?`, inputs only through env (`PROOF_ADMIN_HDR`, `BASE_URL`, `DD_CA_FILE`), `say(pid, ok, detail)` prints `PROOF: <ID> PASS|FAIL <detail>`, and `get()` refuses multi-page responses:
  ```python
  def say(pid, ok, detail):
      print("PROOF: {} {} {}".format(pid, "PASS" if ok else "FAIL", detail))
      return ok
  ```
  After the heredoc, copy the "exited non-zero without reporting a failed assertion" guard (L1044 / L1177-1178).
- Readonly identities (L94-113): add Phase 28 identities as `readonly PROOF_DEDUP_PRODUCT=...` and so on. Readonly names must be `export`ed, not command-prefix assigned, before a Python heredoc (the comment at L809-812).
- Pass the admin token only through `-H "@${admin_hdr}"`. Never put it on argv, and never enable xtrace (L67-69).

**Where the new block goes:** after `prove_http_refusal` (L1442) and before `proof_finish` (L1444), so every Phase 27 assertion still runs with dedup off (RESEARCH "Proof ordering", A4).

**Header docstring to update:** the `--hook` description (L50-58) and the assertion-group list (L62-65):
```bash
# Assertion groups (D-20): P-EXTRACT P-TLS P-ADMIN-TOKEN P-USER
# P-IMPORTER-TOKEN P-GATE P-RUN1 P-CONTEXT P-TESTS P-COUNTS (run 1, 27-05);
# P-RUN2 P-SCHEDULE P-HOSTILE P-SCOPE P-CLEANUP P-REFUSE P-NOMATCH P-INSECURE
# (27-06); P-HTTP (27-11, CR-01). Every body run uses the ci-importer token.
```
Add `P-CONFIGURE P-IDEMPOTENT P-DEDUP-BRANCH P-CROSSTOOL P-REPARENT P-DISPOSITION P-SUPPRESS (28-xx)`. The bootstrap script runs with the **admin** token, which is an explicit exception to "every body run uses the ci-importer token". State it in the comment. `--extract-only` (L269) is unaffected unless the planner adds a static check on the configure script.

**Delta for P-DEDUP-BRANCH (RESEARCH Pitfall 7):** the harness has only `DD_PROOF_REPORTS`. The delta must be derived inside `$PROOF_DIR` from those reports (for example a trimmed `trivy-fs.json` for main), not from a new committed fixture. Otherwise the `fixtures/` rules in both repositories apply.

---

### `.github/workflows/defectdojo-import-proof.yml` (CI config)

**Analog:** same file L41-51:
```yaml
on:
  workflow_dispatch: {}
  pull_request:
    paths:
      - .github/workflows/security.yml
      ...
      - scripts/defectdojo-import-proof.sh
      - scripts/defectdojo-live-smoke.sh
      - kubernetes/defectdojo/**
```
Add `- scripts/defectdojo-configure.sh` (RESEARCH Pitfall 6). Update the header comment L2-10 ("Proves ... run-1 import, in-place reimport, ...") and the WHY-THE-PATHS-FILTER paragraph L29-32 to name the dedup/triage proof and the bootstrap script. The `prove-import` job (L77-122) needs no step change: the new block runs inside the same `bash scripts/defectdojo-import-proof.sh dd-reports`. Check `timeout-minutes: 60` (L85) against the added runtime.

---

### `docs/adr/adr026-<slug>.md` (NEW, ADR)

**Analog:** `docs/adr/adr025-defectdojo-import-https-only.md` (ADR-023 and ADR-024 use the same skeleton).

Header block (L1-17):
```markdown
# ADR-025: DefectDojo CI Import Refuses Non-HTTPS URLs

**Status:** Accepted
**Date:** 2026-09-25
**Addresses:** DDOJO-02 — `security-platform` CI scan jobs automatically import SARIF/JSON findings into
DefectDojo after each run — and code-review finding CR-01 (27-REVIEW, critical)

This record lives in this documentation repository. The public `security-platform` workflow
`security.yml` cites it by number ...
```
The second paragraph is the cross-repo citation and no-environment-values disclaimer. Reuse it: `values.yaml` comments, `TRIAGE.md` and `defectdojo-configure.sh` will cite "ADR-026" by number from the public repository.

Section skeleton: `## Context` (bullets with bold lead-ins, L19-43), `## Decision` (numbered, L45-87) with `### Measured evidence` (L89-109, run IDs and assertion counts), `## Consequences` using `**Improved:**`, `**Tradeoff — ...**`, `**Changed count — ...**`, `**Hand-forward — Phase 29.**` (L111-132), and `## What was NOT verified` (numbered, L134-164).

Content per D-18: dedup scope (D-01), the cross-tool outcome with the measured table (RESEARCH §Cross-Tool Measurement L129-139, D-07), the D-02 re-parent finding (Pattern 3), config homes (D-20 chart guards, D-10/D-21/D-22 bootstrap), the triage system of record (D-13/D-14), the dispositions and Under Review mapping (D-15/D-23), SLA excluded (D-16/D-21). The superuser-token split is a deliberate non-regression of 27 D-10 (Pitfall 2). ADR-024 L205 ("Hand-forward — Phase 28 owns deduplication") is the thread this record closes. Do not edit ADR-024; supersede in prose as ADR-025 L47-50 does. Slug suggestion, in the style of the existing names: `adr026-defectdojo-dedup-product-wide-and-triage-on-default-branch.md`.

---

### `docs/adr/README.md` (doc index)

**Analog:** L35:
```markdown
| [ADR-025](adr025-defectdojo-import-https-only.md) | DefectDojo CI Import Refuses Non-HTTPS URLs | 2026-09-25 | Accepted |
```
Append one row after it. Nothing else changes (append-only).

---

### `docs/adoption-guide.md` (doc)

**Analog:** §12 "Enable DefectDojo Import" (L599-818), subsection style `### Caveats` (L796-804) and `### Measured` (L806-818). Cross-reference bullets in §14 (L909-913):
```markdown
- [ADR-025](adr/adr025-defectdojo-import-https-only.md) — the DefectDojo import refuses non-https
  URLs (CR-01), the SCHEME gate and the P-HTTP proof.
```
Add an ADR-026 bullet in §14 and a short `### Deduplication and Triage` subsection **inside §12** that links the runbook. The gate's section scan (below) only sees §12, so the needle must sit there.

---

### `scripts/check-adoption-guide.sh` (test, offline gate)

**Analog:** DEFECTDOJO-SECTION (L263-296). Extend the needle list:
```python
DD_REQUIRED = [
    "DEFECTDOJO_URL", "DEFECTDOJO_API_TOKEN", "DEFECTDOJO_PRODUCT_TYPE",
    "DEFECTDOJO_INSECURE", "DEFECTDOJO_CA_CERT",
    "is_staff", "reachable", "closed", "scheduled-security.yml", "secrets:",
    "must be https://",
]
```
Add the runbook filename (for example `"TRIAGE.md"`) and optionally `"defectdojo-configure.sh"`, with a comment line in the style of L269 (`# CR-01 / ADR-025 — the https requirement must stay documented.`), for example `# Phase 28 D-17 — the triage runbook link must stay documented.` The section is bounded by the next `## <n>. ` heading (L284-288). There is no count literal: the script prints `PASSED N / FAILED 0` (L312-320), and the check count does not change because a needle is added to an existing check.

---

### `.planning/REQUIREMENTS.md` (tracking)

**Analog:** L22-23 and L52-53:
```markdown
- [x] **DDOJO-02**: `security-platform` CI scan jobs automatically import SARIF/JSON findings into DefectDojo after each run
| DDOJO-02 | Phase 27 | Complete |
```
Flip L24-25 to `[x]` and L54-55 to `Complete`. Do this only after the phase-gate evidence exists (D-12).

## Shared Patterns

### Token and credential handling (D-10, 27 D-10/D-18)
**Source:** `security.yml` L1739-1742 (`write_private` 0600, `O_EXCL`), L1828 (header file written after the https refusal), L1880-1890 (removed in `finally`), and proof L67-69 ("never placed on any argv and never echoed. xtrace is never enabled").
**Apply to:** `defectdojo-configure.sh`, the new proof block.
The bootstrap token is **superuser** (RESEARCH Pitfall 2), not the CI `ci-importer` token. Document it as operator-held, never a GitHub secret.

### https-only, verified TLS (ADR-025)
**Source:** `security.yml` L1795-1799 (refusal first), L1758 (`--proto =https --proto-redir =https`).
**Apply to:** `defectdojo-configure.sh`. No `-k`, no insecure option (D-10). The ADR-025 SCHEME gate (`check-workflow-uploads.sh`) only covers `security.yml`, so the new script's refusal is proven by the kind proof, or by a `--scheme-only`-style offline case if the planner adds one (P-HTTP analog: proof L532-602).

### Three-way exit codes and reporting every failure
**Source:** `check-defectdojo-chart.sh` L23-30, L112-116 (`FAILURES+=`), L476-485. Proof L76-81.
**Apply to:** all scripts. 0 = pass, 1 = defect or assertion failure, 2 = preflight or infrastructure. No silent fallbacks (`|| true` only where a no-match grep is an expected pass, as at L450-456 with an explicit `rc` check).

### WHY-comments citing decision IDs
**Source:** `values.yaml` L25-103, and every gate check header (`# ── N. NAME ──` plus rationale).
**Apply to:** values, gate checks, proof block, configure script. Cite `D-20`..`D-23` / `ADR-026`.

### Script invocation rule
Every script runs as `bash scripts/<name>.sh`. Never `chmod +x` (CLAUDE.md; each analog header says so). The new `defectdojo-configure.sh` must carry the same header line.

### Pinned-source evidence
Every setting and field name is cited to 3.3.200 source or measured (CONTEXT "Established Patterns"). Comments cite `settings.dist.py` / `helper.py` line refs as in RESEARCH, not latest docs.

## Planner Flags (constraints not stated in CONTEXT/RESEARCH)

1. **Runbook link vs `RAW-GITHUBUSERCONTENT-PIN`.** `check-adoption-guide.sh` L199-207 fails any `raw.githubusercontent.com` URL without `/v1/`. This phase moves no tag (D-20; no `security.yml` change), so a `/v1/` link to `TRIAGE.md` would 404 until a later `v1` move. The guide has **zero** `github.com/.../blob/...` links today (all security-platform references are raw `/v1/` URLs or `uses: ...@v1`). Options: (a) a `https://github.com/OttawaCloudConsulting/security-platform/blob/main/kubernetes/defectdojo/TRIAGE.md` link, which passes the gate but is a new link convention and points at a moving branch; (b) name the path in code font plus the repository, with no URL; (c) cut a chart or docs tag. The planner must choose and record why.
2. **README L51 is stale** (DDOJO-02 "Planned (Phase 27)", but Complete in REQUIREMENTS.md). It sits next to D-19's rows. Decide whether to fix it and record the decision.
3. **The gate count moves in 4 places, not 3**: gate L19, L96, L474, and `kubernetes/defectdojo/README.md` L285.
4. **Clone branch.** `repos/security-platform` is checked out on `fix/phase-27-https-only` (HEAD `ba3683a`), not `main`. Executors must `git fetch` and branch from `origin/main` (ADR-025 records merge `917352c` there) before editing.
5. **The admin token file is deleted mid-proof** (proof L695). This fixes the configure script's input contract (header file vs token file); see the configure-script gap 2.
6. **PLACEHOLDER-ONLY grep** (gate L466) applies to the new `values.yaml` comments: no "homelab", "occ-", "letsencrypt" or "ottawacloudconsulting".

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `repos/security-platform/kubernetes/defectdojo/TRIAGE.md` | doc (runbook) | n/a | No runbook exists in either repository. Use README.md prose conventions and RESEARCH Patterns 4-7 for content |

Partial: `scripts/defectdojo-configure.sh` has no single analog. It combines the proof script's bash shell with the `dd-delete` Python client. The JSON-body PATCH and the non-list response handling are new (configure-script gap 1).

## Metadata

**Analog search scope:** `repos/security-platform/{scripts,kubernetes/defectdojo,.github/workflows}`, `docs/adr/`, `docs/adoption-guide.md`, `scripts/`, `.planning/REQUIREMENTS.md`
**Files scanned:** 14 (values.yaml, Chart.yaml, README.md, check-defectdojo-chart.sh, defectdojo-import-proof.sh (targeted ranges), security.yml (dd-delete range), defectdojo-import-proof.yml, set-required-checks.sh (header only), adr023/024/025, adr/README.md, adoption-guide.md (§12, §14), check-adoption-guide.sh)
**Pattern extraction date:** 2026-09-25
