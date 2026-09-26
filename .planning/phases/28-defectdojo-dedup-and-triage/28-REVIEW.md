---
phase: 28-defectdojo-dedup-and-triage
reviewed: 2026-09-26T23:02:10Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - repos/security-platform/scripts/defectdojo-configure.sh
  - repos/security-platform/scripts/defectdojo-import-proof.sh
  - repos/security-platform/scripts/check-defectdojo-chart.sh
  - repos/security-platform/.github/workflows/defectdojo-import-proof.yml
  - repos/security-platform/kubernetes/defectdojo/values.yaml
  - repos/security-platform/kubernetes/defectdojo/Chart.yaml
  - repos/security-platform/kubernetes/defectdojo/README.md
  - repos/security-platform/kubernetes/defectdojo/TRIAGE.md
  - scripts/check-adoption-guide.sh
findings:
  critical: 1
  warning: 4
  info: 6
  total: 11
status: issues_found
---

# Phase 28: Code Review Report

**Reviewed:** 2026-09-26T23:02:10Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Scope: the security-platform diff `917352c..c8027e6` (merged PR #23; the working tree at `c77e4f4` is byte-identical to `c8027e6`) and the Phase 28 change to `scripts/check-adoption-guide.sh` (commit 83f7c02). For `defectdojo-import-proof.sh`, only the Phase 28 additions were reviewed.

What was run, not just read:
- `bash scripts/check-defectdojo-chart.sh` gave `PASS - 22 checks, 0 failures`.
- `bash scripts/check-adoption-guide.sh` gave `PASSED 16 / FAILED 0`, and DEFECTDOJO-SECTION carries all 13 strings.
- `defectdojo-configure.sh` was probed offline and against a local self-signed TLS server. The results are cited in CR-01, WR-01 and WR-02.
- The README `kubectl exec deploy/defectdojo-django -c uwsgi` command was checked against the vendored subchart 1.9.53 templates. With release name `defectdojo`, the fullname is `defectdojo`, the Deployment is `defectdojo-django` and the container is `uwsgi`. The command is correct, so there is no finding.

The main concern is the new superuser bootstrap, `defectdojo-configure.sh`. It says TLS is "always verified" with "no option to switch it off", but it honours the operator's curlrc, and a curlrc `insecure` line silently turns verification off before the superuser token is sent. This was demonstrated, not inferred. The script's exit-code contract and its token validation also have gaps. The proof harness additions are careful: tokens are never on argv, the admin token is masked with bash builtins, every Python assertion script reports its own failure, and the harness backstops a script that crashes. Its defects are minor. TRIAGE.md has one substantive workflow defect: its canonical Under Review query leaves out every Trivy finding.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: A curlrc `insecure` line silently disables TLS verification for the superuser-token bootstrap

**File:** `repos/security-platform/scripts/defectdojo-configure.sh:37-41, 131, 144`
**Issue:** The header comment makes two claims that contradict each other. Line 39 says "TLS is always verified; there is no option to switch it off". Lines 40-41 say "Plain curl is called, so a curlrc under CURL_HOME is honoured". The `api()` command (line 131) calls curl without `-q`/`--disable`, so `~/.curlrc`, or `$CURL_HOME/.curlrc`, is read. A curlrc containing `insecure` (common on developer workstations that deal with self-signed certificates) turns verification off. The script never checks `%{ssl_verify_result}`: it checks only the HTTP code (line 144). By contrast, the harness's own `write_dedup_py` `get()` checks `verify != "0"`. This is the one script that sends a **superuser** token.

Reproduced: a local HTTPS server with a self-signed certificate on `localhost:8443`, `CURL_HOME` holding `insecure` and `verbose`, and no `DEFECTDOJO_CA_FILE`. The script completed the TLS handshake, sent the request with the Authorization header and printed `FAILED: GET /api/v2/system_settings/ http=500 ...`. Verification would have refused this certificate, so the token went to an unverified peer.

Secondary: on a failure with an empty body, line 145 echoes up to 500 bytes of curl stderr. With `verbose` or `trace-ascii` in the curlrc, the request headers, including `Authorization: Token ...`, go to stderr or a trace file. In the reproduction the 500-byte truncation cut the output off in the TLS handshake lines, so the token was **not** observed on screen. This is a latent leak path, not a demonstrated one.

The P-TLS guard in the harness (import-proof.sh:2134) rejects `insecure` in the harness's **own** curlrc only. It does not protect an operator running the script.

**Fix:** Stop reading ambient curl config. Give the harness an explicit hook for its `resolve` entry instead, and fail closed on an unverified result:
```python
cmd = ["curl", "-q", "-sS", "--proto", "=https", "--proto-redir", "=https",
       "-X", method, "-o", resp_path, "-w", "%{http_code} %{ssl_verify_result}"] + tls_args
resolve = env.get("DEFECTDOJO_RESOLVE", "")   # harness: host:port:127.0.0.1
if resolve:
    cmd += ["--resolve", resolve]
...
code, _, verify = (proc.stdout or "000 -").strip().partition(" ")
if verify != "0":
    print("FAILED: {} {}: TLS verification result {} (must be 0)".format(method, path, verify))
    raise Failed()
```
Change lines 40-41 of the comment to match. Add an offline P-CONFIGURE-GUARD case that runs with a `CURL_HOME` containing `insecure` against a self-signed endpoint, and asserts a refusal. Also stop echoing raw curl stderr on failure, or scrub `Authorization:` lines from it.

## Warnings

### WR-01: A token file that is unreadable or is a directory crashes with a traceback and exit 1, not the documented preflight exit 2

**File:** `repos/security-platform/scripts/defectdojo-configure.sh:181-191` (contract at 55-60)
**Issue:** The script `os.stat`s the token file and checks its mode, then calls `open()` outside any `try`. A mode-000 file, or a directory at the path, passes the `st_mode & 0o077` check because the owner bits are not examined. `open()` then raises `PermissionError` or `IsADirectoryError`. That exception is neither `Failed` nor `Preflight`, so it escapes as a Python traceback with exit 1. Reproduced for both cases. The header documents exit 2 for "the token file is missing, empty or group/other-readable". A wrapper that separates preflight (2) from API failure (1) will misclassify these. The "does not exist or cannot be read" message on line 184 is also misleading, because `stat` succeeds on an unreadable file. P-CONFIGURE-GUARD covers only the empty-variable and 0644 cases.
**Fix:**
```python
if not stat.S_ISREG(st.st_mode):
    print("FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE {!r} is not a regular file".format(token_file), file=sys.stderr)
    raise Preflight()
...
try:
    with open(token_file, encoding="utf-8") as handle:
        token = handle.read().strip()
except OSError as exc:
    print("FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE {!r} cannot be read: {}".format(token_file, exc.strerror), file=sys.stderr)
    raise Preflight()
```
Add `configure-unreadable` (mode 000) and `configure-missing` cases to `prove_http_refusal`.

### WR-02: The token content is not validated, so a multi-line token file injects extra request headers

**File:** `repos/security-platform/scripts/defectdojo-configure.sh:190-203`
**Issue:** `token = handle.read().strip()` removes only the outer whitespace. Line 203 writes `"Authorization: Token {}\n".format(token)` to the header file, and curl `-H @file` sends **each line** as a header. A file containing `abc\nX-Other: 1` was accepted and produced two headers (reproduced: the request was attempted, not refused). A file holding `Token abc`, the README's own prefix pitfall (line 52), produces `Authorization: Token Token abc`, which surfaces only as a confusing 401. The file is operator-controlled, so the impact is limited. Still, the script's security posture rests on the header file holding exactly one well-formed header.
**Fix:**
```python
if not re.fullmatch(r"[A-Za-z0-9]{20,128}", token):
    print("FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE {!r} must hold one bare token "
          "(no 'Token ' prefix, no whitespace or extra lines)".format(token_file), file=sys.stderr)
    raise Preflight()
```
DefectDojo tokens are 40 hex characters, so a tighter `[0-9a-f]{40}` would also work.

### WR-03: The TRIAGE.md Under Review query leaves out every Trivy finding, so the state model does not hold for the largest finding source

**File:** `repos/security-platform/kubernetes/defectdojo/TRIAGE.md:31, 35, 42, 44, 85`
**Issue:** Line 31 says every finding is in "exactly one" state. Line 35 says a finding leaves Under Review "when you set Verified". Line 42 defines Under Review as `verified=false`. The canonical API query (line 85) filters `verified=false`. Line 44 then records that Trivy findings **arrive** `verified=true`. So the runbook's own untriaged queue returns zero Trivy findings. For Trivy, "Under Review" and "Verified/Active" cannot be told apart, which means a triager cannot record "confirmed real" as distinct from "not yet looked at". Trivy is the largest SCA source (the proof's PR engagement had 155 findings, mostly Trivy). Line 44 acknowledges the symptom as a footnote, but the primary query and the state table are still wrong for the common case. A triager following the example query will never see Trivy findings.
**Fix:** Choose one of these:
- Make the canonical Under Review query not depend on `verified`, and show the queue per parser.
- Define "triaged as real" by a signal DefectDojo does not preset, such as a `triaged` tag or a note, and query `tags__not=triaged` or similar.
- Have the import send `verified=false` explicitly (security.yml is out of this phase's scope, so note it as a follow-up).

Then correct lines 31, 35 and 42 so the state table matches what is measured.

### WR-04: The P-HTTP configure cases claim "refused before the token file is read" but do not test the order

**File:** `repos/security-platform/scripts/defectdojo-import-proof.sh:665-677, 704`
**Issue:** The PASS detail asserts "refused before the token file is read". Both `configure-http` and `configure-noscheme` point `DEFECTDOJO_ADMIN_TOKEN_FILE` at a valid 0600 dummy file. A regression that moved the https check after the token read would still exit 1 with "must be https://", and the assertion would still pass. The ordering is a documented ADR-025 guarantee (configure.sh:37, 172), so the proof overstates what it proves.
**Fix:** In the two http cases, set `DEFECTDOJO_ADMIN_TOKEN_FILE="${PROOF_DIR}/does-not-exist.token"`. The bash preflight checks only that the variable is non-empty. Exit 1 with `must be https://`, and no `FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE` line, then proves the refusal came first. Alternatively, remove the unproven clause from the PASS text.

## Info

### IN-01: A stale "not yet measured" comment contradicts the runbook's "Measured" claims

**File:** `repos/security-platform/scripts/defectdojo-import-proof.sh:1080`
**Issue:** `assert_disposition` says the FP/OOS/RA tuples are "Source-derived (RESEARCH Pattern 4), not yet measured". TRIAGE.md lines 37-39 present the same tuples as "Measured".
**Fix:** Update the comment to cite the measured run.

### IN-02: The FAILED refusal goes to stdout, while FATAL preflight lines go to stderr

**File:** `repos/security-platform/scripts/defectdojo-configure.sh:146, 151, 161, 174, 216, 222`
**Issue:** The https refusal and the API failures print to stdout. The preflight FATAL lines print to stderr. A caller that captures only stderr for errors misses the security refusal.
**Fix:** Add `file=sys.stderr` to the `FAILED:` prints.

### IN-03: `--proto-redir` is dead without `-L`

**File:** `repos/security-platform/scripts/defectdojo-configure.sh:131`
**Issue:** curl does not follow redirects without `-L`, so `--proto-redir =https` never takes effect. A 30x surfaces as `http=301` and fails, which is safe. The flag only suggests a redirect policy that does not exist.
**Fix:** Keep it as defence in depth, but say so in a comment, or remove it.

### IN-04: If P-DEDUP-MODE fails, the later dedup assertions rely on a settle poll that can settle before dedup has started

**File:** `repos/security-platform/scripts/defectdojo-import-proof.sh:975-999, 1497`
**Issue:** A P-DEDUP-MODE failure is a `proof_fail`, not an abort. `wait_dedup_settled` accepts two equal snapshots 5 s apart, which also happens when async dedup has not started yet (for example, "0 duplicate of N" twice). The run still fails overall because P-DEDUP-MODE is counted. However, the P-DEDUP-BRANCH, P-SUPPRESS and P-REPARENT failures that follow can then be misleading noise.
**Fix:** Make a P-DEDUP-MODE failure `proof_abort`, or require the settle poll to see a non-zero duplicate count where duplicates are expected.

### IN-05: The dedup algorithm map is pinned to a hard-coded set of 7 scan types, not derived from security.yml

**File:** `repos/security-platform/scripts/check-defectdojo-chart.sh` (check 22, `dedup_want`) and `repos/security-platform/kubernetes/defectdojo/values.yaml` (`DD_DEDUPLICATION_ALGORITHM_PER_PARSER`)
**Issue:** Both claim to cover "every scan type security.yml imports", but nothing cross-checks them against the workflow. If a scanner is added to security.yml, its algorithm is not restated, and the gate still passes.
**Fix:** Have the gate extract the scan types from `.github/workflows/security.yml`, or from the import-proof table at import-proof.sh:2334, and compare them with the map's keys.

### IN-06: The adoption-guide gate needles are loose substrings

**File:** `scripts/check-adoption-guide.sh:276`
**Issue:** `"blob/main/kubernetes/defectdojo/TRIAGE.md"` matches a link to any org or repository. `"defectdojo-configure.sh"` matches a bare mention, for example in a "do not run" sentence. The gate proves the strings are present, not that the link is correct.
**Fix:** Pin the needle to `OttawaCloudConsulting/security-platform/blob/main/kubernetes/defectdojo/TRIAGE.md`, and require `bash scripts/defectdojo-configure.sh` (the invocation form).

---

_Reviewed: 2026-09-26T23:02:10Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
