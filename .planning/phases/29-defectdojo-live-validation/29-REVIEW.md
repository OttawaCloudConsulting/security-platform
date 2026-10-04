---
phase: 29-defectdojo-live-validation
reviewed: 2026-09-29T22:45:24Z
depth: standard
files_reviewed: 29
files_reviewed_list:
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/docs/adoption-guide.md
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/docs/adr/adr027-defectdojo-homelab-live-validation.md
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/docs/adr/adr028-repo-scoped-arc-runner-for-private-defectdojo-import.md
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/docs/adr/README.md
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/scripts/check-adoption-guide.sh
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/.github/workflows/defectdojo-import-proof.yml
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/.github/workflows/security.yml
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/kubernetes/defectdojo/README.md
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/kubernetes/defectdojo/TRIAGE.md
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/check-workflow-uploads.sh
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-homelab-validate.sh
  - /Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-lifecycle-assert.sh
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/.gitleaksignore
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/automation/argocd/templates/projects.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/argocd-overrides.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/Chart.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/README.md
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/templates/sealedsecret-arc-github-pat.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-systems/argocd-overrides.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-systems/README.md
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/argocd-overrides.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/Chart.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/README.md
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/certificate.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/sealedsecret-defectdojo-postgresql-specific.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/sealedsecret-defectdojo-valkey-specific.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/sealedsecret-defectdojo.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/service.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-cluster-config/docs/upgrade/cilium-l2-vantage-host-runbook.md
findings:
  critical: 0
  warning: 8
  info: 3
  total: 11
status: issues_found
---

# Phase 29: Code Review Report

**Reviewed:** 2026-09-29T22:45:24Z
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

I reviewed all 29 files at standard depth. For the `security-platform` files I used the phase diff
(`c8027e6..fdabac9`); for the overlay repositories I used the phase commits (`ee35cfb`, `db5aae1`,
`b2cacd0`, `ad8c5db`, `1070fac`, and cluster-config `5c65ffb`). I read the two new shell helpers
line by line.

No Critical issue was found. Things I checked and found sound:

- **Secrets:** no plaintext secret. `gitleaks detect --no-git` over `application-sets/platform`
  reported "no leaks found". Every `.gitleaksignore` line pin matches the current `encryptedData`
  line (defectdojo 39-42, postgresql 39-40, valkey 31, arc-github-pat 39).
- **Routing and gates:** the `runs-on` routing shape is correct, and the JOB-SHAPE and
  SIDE-CHANNEL-SHAPE gate additions are correct.
- **Script permissions:** neither new script has the executable bit set.

The defects are in these areas:

- **Evidence traceability:** ADR-027 quotes check IDs that the shipped helper does not emit.
- **Gates that pass when they should fail:** a guide gate needle that matches unrelated text, and a
  second-sync assertion that turns into a SKIP.
- **Weak assertions:** the step-5 check compares counts only, and pagination checks no ids.
- **Robustness of the live gate:** it breaks on stock macOS LibreSSL, and no curl call has a timeout.
- **An inferred triage-documentation gap:** trivy-image dispositions on `ci/main` probably do not
  survive the next default-branch commit.

Each finding is labelled either **Verified** (reproduced or read from evidence) or **Inferred**
(reasoned from the code or from measured behaviour, but not reproduced).

Excluded because they are already accepted: trivy-image cross-branch non-dedup itself (follow-up
"b"), KIND-CELERY-PING, SealedSecret ciphertext, the self-hosted runner on a public repository and
the fork-PR residual risk, the breadth of the PAT permission, and the proof-workflow stall.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: ADR-027 cites step-2 check IDs that the shipped helper never emits (Verified)

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/docs/adr/adr027-defectdojo-homelab-live-validation.md:183-189` (and `:286-288`)
**Issue:** ADR-027 records the amended step 2 as passing `D11-STEP2A-ENGAGEMENT`,
`D11-STEP2A-READ-GUARD` and `D11-STEP2A-EXCLUSION-KEY`. These IDs appear in only two places: the
planning helper `.planning/phases/29-defectdojo-live-validation/29-16-step2-amended.sh` and its
output `evidence/29-16-step2-amended.txt`.

The committed `repos/security-platform/scripts/defectdojo-lifecycle-assert.sh` (lines 621, 681-685)
emits `D11-STEP2-ENGAGEMENT` and `D11-STEP2-EXCLUSION-KEY`. It has no READ-GUARD check; the
engagement guard is an internal `error()` in `engagement_findings`. Its pass message wording also
differs from the one quoted at ADR line 187.

29-18-SUMMARY line 92 states that the committed exclusion (commit `0f401f7`) was verified by
"offline replay" only. Lines 286-288 of the ADR say the exclusion "shipped", right next to live PASS
evidence. A reader would conclude that the shipped helper produced that evidence, and it did not.
**Fix:** ADRs are append-only once Accepted, so do not rewrite the paragraph. Add an erratum
subsection, and let the orchestrator or operator decide whether even an erratum is acceptable on an
Accepted record. Suggested text:

```markdown
### Erratum (2026-09-29)
The `D11-STEP2A-*` IDs above were emitted by the one-off planning helper
`29-16-step2-amended.sh`, not by `scripts/defectdojo-lifecycle-assert.sh`. The shipped
`assert-pr-duplicates` exclusion (`0f401f7`) emits `D11-STEP2-ENGAGEMENT` and
`D11-STEP2-EXCLUSION-KEY`, has no READ-GUARD check, and was verified by offline replay against
`pr-branch-snapshot.json`, not by a live run.
```

The alternative is to re-run the shipped `assert-pr-duplicates` live on the next PR and record that
output.

### WR-02: The new check-adoption-guide.sh needle "queue" does not detect removal of the queue-not-fail caveat (Verified)

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/scripts/check-adoption-guide.sh:278`
**Issue:** `"queue"` is also matched by "untriaged-queue" at `docs/adoption-guide.md:852`, which
sits inside the same DefectDojo section. I removed the two queue-caveat lines (guide lines 808-809)
from a scratch copy and ran `bash scripts/check-adoption-guide.sh <copy>`. It printed
`PASS: DEFECTDOJO-SECTION ... carries all 16 required strings` and `PASSED 16 / FAILED 0`. The gate
that the comment says makes "the queue-not-fail caveat ... stay documented" does not do that.
**Fix:** use a needle that only the caveat carries:

```python
"DEFECTDOJO_RUNS_ON", "all_external_contributors", "queued for about 24 hours",
```

### WR-03: HOMELAB-TLS-* fails on stock macOS because it uses `openssl x509 -ext` (Verified)

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-homelab-validate.sh:464-465, 395-400`
**Issue:** the SAN read runs `openssl x509 -noout -ext subjectAltName`. `/usr/bin/openssl` on this
machine is LibreSSL 3.3.6, and its `x509 -help` has no `-ext` option. The hard-tier preflight only
checks that some `openssl` is on PATH. So on any macOS host without Homebrew OpenSSL first on PATH,
`cert_rc` is non-zero and both TLS checks FAIL with "could not read the subjectAltName of the
certificate served". That message blames the deployment, not the tool.
**Fix:** read the SAN list in a form that works on both OpenSSL and LibreSSL:

```bash
openssl s_client -connect "$connect" -servername "$host" </dev/null 2>/dev/null \
  | openssl x509 -noout -text > "$OUT/${id}-cert.txt" 2>&1 || cert_rc=$?
grep -A1 'Subject Alternative Name' "$OUT/${id}-cert.txt" > "$OUT/${id}-san.txt"
```

The other option is to probe `openssl x509 -help 2>&1 | grep -q -- '-ext '` in the preflight and
exit 1 with "OpenSSL >= 1.1.1 required".

### WR-04: TRIAGE.md limits the trivy-image gap to "across branches", but the same mechanism probably loses ci/main image dispositions at every new default-branch commit (Inferred, not measured)

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/kubernetes/defectdojo/TRIAGE.md:14, 17-25`; `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/kubernetes/defectdojo/README.md:242`
**Issue:** this is a corollary of the accepted cross-branch item, not a restatement of it.

- **Why it probably happens:** the phase measured that the `scan-target:<sha>` tag keeps image
  findings from matching across two SHAs. Two commits on `main` also differ in SHA. So a
  `ci/main` reimport at a new SHA should create new trivy-image findings, and `close_old_findings`
  should close the old ones. Any False Positive or Risk Accepted disposition set on a `ci/main`
  image finding would be left on a closed finding and would not carry forward.
- **Why the rule is misleading:** "Triage on the default branch only" (TRIAGE.md:17) is the
  documented workflow, and for image findings it would not hold past the next merge.
- **Why nothing caught it:** every `main` import in the phase ran at head `2fda1ac`: the baseline
  (`29-15-baseline-run.json`), the step-4 reimport (`29-16-reimport-run.json`, all jobs `head_sha`
  `2fda1ace…`) and the cron run. D11-STEP4 therefore never tested disposition survival across a
  SHA change. The RA fixture (finding 22) was also a Trivy **fs** finding, not an image finding.

**Fix:**

1. Widen the TRIAGE.md caveat now. Suggested text: "trivy-image findings are also expected to be
   re-created on each default-branch commit, so a disposition on a `ci/main` image finding is not
   expected to survive the next merge (inferred, not measured; follow-up b)."
2. Verify it after the first scheduled import at `fdabac9` or later. Compare the ids of the
   `ci/main` trivy-image Test findings against `evidence/main-after-close-snapshot.json`. New ids
   together with `is_mitigated=true` on the old ones confirm the inference.
3. Record the outcome in a new ADR or the follow-up-b record.

### Resolution (Phase 29.4, 2026-10-04)

WR-04 is closed by Phase 29.4. The container job in `security.yml` now builds and scans the fixed tag
`scan-target:ci` instead of `scan-target:${{ github.sha }}` (security-platform PR #32, merge `2dccff5`), released in
`v1.3.0` (annotated tag object `21c5037` on `aa48081`; `v1` moved to `aa48081`). The pre-fix state was consistent
with the inference above: the `ci/main` trivy-image Test held 59 mitigated findings on `scan-target:2fda1ac…`, an earlier main
SHA (29.4-05-SUMMARY).
After the fix, D-11 measured it live: between two `ci/main` imports at different main SHAs (`2dccff5` and `aa48081`,
dispatch 37230464825), 60 of 60 trivy-image finding ids persisted, 0 were recreated and there was no drift; the
reimport left all 60 untouched (`.planning/phases/29.4-fix-trivy-image-cross-branch-dedup-replace-scan-target-githu/evidence/29.4-08-d11-persist.json`).
The TRIAGE.md and README caveats were rewritten in PR #34 instead of widened. ADR-031 records the decision and the
evidence. The finding text above is left as written.

### WR-05: `api_get_all` pages by offset with no stable order and checks only the row count (Inferred)

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-lifecycle-assert.sh:429-465`
**Issue:** pages are fetched with `limit=250&offset=N`, and no ordering is requested. The only
integrity checks are "count unchanged while paging" and `got == count`. Without a deterministic
ORDER BY on a unique key, PostgreSQL may return a row on two pages and skip another. Both checks
still pass, and every set-based assertion that follows (snapshots, the duplicates-point-to-main
check, NO-DANGLING-DUPLICATE) runs on a corrupted set. The header's PAGINATION paragraph presents
these reads as exact. It is latent today because every engagement has fewer than 250 findings, so
every read fits on one page.
**Fix:** at minimum, assert that the ids are unique before writing `$out`:

```bash
if [[ "$(jq -s 'map(.id) | (unique | length) == length' "${out}.rows")" != "true" ]]; then
  API_ERROR="GET ${path}: duplicate ids across pages (unstable ordering)"; return 1
fi
```

Also add an explicit ordering parameter, but first check the exact name DefectDojo 3.3.200 accepts
on each endpoint (for example `ordering=id`). An unrecognised filter is silently ignored, as the
script's own FILTER GUARDS paragraph notes.

### WR-06: D11-STEP5-MAIN-COUNT-UNCHANGED compares counts only, though the id diff is already computed (Verified by reading)

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-lifecycle-assert.sh:846-855`
**Issue:** `main-count.json` carries `added` and `removed` id arrays (line 850). The verdict at line
851 still tests only `.snapshot_count == .count_now`. If closing the PR removed one `ci/main`
finding and anything added another (a concurrent scheduled import, say), the check would PASS while
the `ci/main` set had changed. That is the same kind of false pass the script header says it exists
to prevent.
**Fix:**

```bash
if [[ "$(jq --arg n "$main_name" '.engagement_name_now == $n and .snapshot_count == .count_now
      and (.added | length) == 0 and (.removed | length) == 0' "${WORK}/main-count.json")" == "true" ]]; then
```

### WR-07: With `--sync-pass second`, a pre-state with null counts produces a SKIP, not a FAIL, and the run can still print ALL PASS (Verified by reading)

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-homelab-validate.sh:991-993` (and `:854-876`, `:1003`)
**Issue:** when the first-pass state was written without `--token-file`, `product_count` and
`finding_count` are `null`. The second pass then only appends a SKIP and sets `idem_ok=0`, so
SECOND-SYNC-IDEMPOTENT neither passes nor fails. Every other check can pass, and the summary prints
`ALL PASS - 7 live check(s) ... 2 sub-check(s) skipped`. That contradicts the script's own rationale:

- `--sync-pass` is never defaulted "so the run cannot pass without ever asserting idempotency"
  (lines 257-259).
- `--token-file` is mandatory on the second pass "because the counts are part of the idempotency
  assertion" (line 280).

The first pass also writes the null-count state file with only a WARNING.
**Fix:** make it a failure on the second pass:

```bash
if [ "$before" = "null" ]; then
  fail "$id" "${label}: the pre-state holds null (captured without --token-file); data preservation cannot be asserted"
  idem_ok=0
```

Alternatively, reject a null-count `--pre-state` at preflight with exit 2 when `--sync-pass second`.

### WR-08: No network call in either helper has a timeout (Verified by reading)

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-homelab-validate.sh:461, 464, 519, 565, 584, 622, 804`; `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-lifecycle-assert.sh:408, 885`
**Issue:** no `curl` call sets `--connect-timeout` or `--max-time`, and `openssl s_client` has no
timeout either. Consider an L2 VIP that is announced but has no ready endpoint (ghostunnel not
Ready), or a node holding the lease that is black-holing traffic. curl then waits for the OS TCP
timeout, and a server that accepts but never answers stalls it with no limit. The header promises
"well under a minute" and "the gate measures the state it finds", but a hung gate produces no
verdict at all.
**Fix:** add `--connect-timeout 10 --max-time 60` to every curl invocation (to the `args` array in
`api_request`, and inline in homelab-validate). For openssl, wrap the call:
`timeout 20 openssl s_client ...` (on macOS, `gtimeout` from coreutils or a bash `read -t` guard).

## Info

### IN-01: homelab-validate hardcodes release-derived object names while claiming no-code-change re-pointing

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-homelab-validate.sh:42-46, 493, 651, 674, 735, 751, 816-818, 936`
**Issue:** design fork 1 says the gate "is re-pointed at another instance with no code change".
However, Secret `defectdojo`, `deploy/defectdojo-django`, `defectdojo-celery-worker`, Job
`defectdojo-initializer` and ServiceAccount `defectdojo` are all literals. They hold only when the
release name contains `defectdojo`. Separately, `kubectl logs deploy/defectdojo-django --since=5m`
(line 651) reads a single pod. With more than one django replica, the foreign-Origin log line can
be on another pod, which causes a spurious FAIL.
**Fix:** add a `--release <name>` flag (or document the naming assumption in the header), and read
the logs with `-l defectdojo.org/component=django --prefix`.

### IN-02: Admin-password decode does not detect a partial base64 failure

**File:** `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/scripts/defectdojo-homelab-validate.sh:500`
**Issue:** in `printf '%s' "$(base64 -d < ...)"`, the exit status is printf's. A `base64 -d` that
prints partial output and then errors is not caught; only a completely empty result is. The login
would then fail with a misleading "200 = credentials rejected".
**Fix:** decode into a variable first and check the status:
`pw="$(base64 -d < "$OUT/admin-pw.b64")" || dec_rc=$?`, then write it with printf.

### IN-03: Runner pods keep an auto-mounted ServiceAccount token in the namespace that holds the decrypted PAT

**File:** `/Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/argocd-overrides.yaml:84-110`
**Issue:** the runner `template.spec` does not set `automountServiceAccountToken: false`. Runner
pods execute workflow code (including maintainer-approved fork PRs, an accepted risk). They run in
`arc-runners`, the namespace where Secret `arc-github-pat` (Administration: RW on security-platform)
is decrypted. The chart's no-permission ServiceAccount has no RBAC today, so the token cannot read
the Secret. Hardening note only.
**Fix:** add `automountServiceAccountToken: false` under `template.spec`. The jobs run only bash,
python3 and curl against DefectDojo, and ARC runners in non-kubernetes container mode do not need
the token.

---

_Reviewed: 2026-09-29T22:45:24Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
