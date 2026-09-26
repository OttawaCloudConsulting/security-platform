---
phase: 27-defectdojo-ci-auto-import
reviewed: 2026-09-25T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - docs/adoption-guide.md
  - docs/adr/adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md
  - docs/adr/adr025-defectdojo-import-https-only.md
  - docs/adr/README.md
  - repos/security-platform/.github/workflows/defectdojo-import-proof.yml
  - repos/security-platform/.github/workflows/pr-security.yml
  - repos/security-platform/.github/workflows/scheduled-security.yml
  - repos/security-platform/.github/workflows/security.yml
  - repos/security-platform/scripts/check-workflow-uploads.sh
  - repos/security-platform/scripts/defectdojo-import-proof.sh
  - repos/security-platform/scripts/defectdojo-live-smoke.sh
  - scripts/check-adoption-guide.sh
findings:
  critical: 0
  warning: 7
  info: 10
  total: 17
status: issues_found
---

# Phase 27: Code Review Report (re-review after gap closure 27-11..27-14)

**Reviewed:** 2026-09-25
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

This review covers two scopes:

- **Outer repository:** `bbb07b7..HEAD`. The changes are ADR-025, the ADR README row, the adoption guide
  TLS paragraph and cross-reference, and the `DD_REQUIRED` needle in `scripts/check-adoption-guide.sh`.
- **Nested `repos/security-platform`:** `0f7e4e1..917352c` (PR #22, fix commit `ba3683a`). The changes
  are `security.yml`, `check-workflow-uploads.sh` and `defectdojo-import-proof.sh`.

The local nested checkout is on `fix/phase-27-https-only`, and `git diff origin/main` is empty, so the
reviewed tree is the merged tree. `pr-security.yml`, `scheduled-security.yml`,
`defectdojo-import-proof.yml` and `defectdojo-live-smoke.sh` are unchanged since `0f7e4e1`. They were
re-read only for context and for carry-forward findings.

### CR-01 status: RESOLVED

The evidence below was observed during this review, not taken from the summaries.

- **Code.** Both bodies refuse a non-https URL as the first statement of `main()`. The check is at
  `security.yml:1426` in dd-import (`return 1`) and at `:1796` in dd-delete (`raise Failed()`). Each
  refusal comes before its `TLS mode:` print (`:1443` / `:1825`) and before its
  `write_private(hdr_path` (`:1456` / `:1828`). A refusal therefore writes no header file, no results
  file and no false `verified-system` label. Every curl in both bodies (`:1499`, `:1758`) carries
  `--proto =https --proto-redir =https`. That makes curl a second, independent barrier: a regression
  that deleted the Python refusal would still not send over `http://`, because curl rejects the protocol
  before connecting.
- **Gate.** `bash scripts/check-workflow-uploads.sh` printed `PASS - 19 checks, 0 failures`.
- **Proof.** `bash scripts/defectdojo-import-proof.sh --scheme-only` printed three `P-HTTP PASS` lines
  (import-http, import-noscheme, delete-http) and `PROOF PASS - 3 assertions`.
- **Documentation.** `bash scripts/check-adoption-guide.sh` printed `PASSED 16 / FAILED 0`, and
  DEFECTDOJO-SECTION found all 11 required strings, including `must be https://`.
- **Downstream effect.** When the import refuses, `dd-verify` still goes red: the outcome is `failure`
  and a `FAILED:` line exists for its message to point to.
- **ADR-025 accuracy.** The line numbers in ADR-025 (1425/1426, 1443, 1456, 1795/1796, 1825, 1828)
  match `origin/main:917352c` exactly. Its references to ADR-024 decision 13 (TLS, D-18), decision 15
  (18 checks) and the 85-assertion proof match ADR-024's text. ADR-024 itself is unmodified, which keeps
  it append-only.

### Did the fix introduce new issues?

It introduced no new correctness or security defects. It did introduce one new Warning and three Info
items:

- **WR-07 (Warning):** the new SCHEME gate is a substring and position check, and a mutant with the
  refusal disabled still passes it. This review demonstrated that mutant.
- **IN-08:** the refusal message can print most of a URL that has no scheme, contrary to ADR-025's
  "never the URL".
- **IN-09:** there is documentation drift, and ADR-025's literal "no `-L` occurs in `security.yml`" is
  false.
- **IN-10:** P-HTTP coverage has gaps.

### Carry-forward

The nested diff touched none of the code paths behind the prior WR-01..WR-06 and IN-01..IN-07. All of
them are **still open, unchanged**, and ADR-025's "What was NOT verified" item 5 says the same for
WR-01..06. The line numbers below are re-derived against `917352c`; some references in the prior
report had drifted.

## Warnings

### WR-01: `close_old_findings=true` is applied to reports whose scan step errored (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1268` (job `if: always() && …`) and `:1464-1522` (import loop, `close_old_findings=true` at `:1492`)
**Issue:** The import job imports every report file that exists. It never checks whether the step that
produced the file succeeded, or whether the report records a scanner error. For example, a Semgrep
JSON with `errors` populated and `results: []` is indistinguishable from a clean scan. With
`close_old_findings=true`, importing that report mitigates every open finding in that Test while
`dd-verify` reports green. The `Verify npm audit reports` step exists because of this failure class,
but the import ignores that step's result. The fix left this unchanged.
**Fix:** have each scan job's report verify step write a per-report `.ok` marker into the artifact.
For any file without a marker, either skip the import or send `close_old_findings=false`. At minimum,
send `close_old_findings=false` for a `semgrep-results.json` whose `errors` array is non-empty.

### WR-02: The import has no default-branch or foreign-head guard (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1445-1452`
**Issue:** On `pull_request` the engagement is always `ci/<GITHUB_HEAD_REF>`. Two cases reimport the
PR's scan into `ci/main` with `close_old_findings=true`:

- a same-repo PR whose head is the default branch, such as a `main` into `release/x` back-merge;
- a fork PR from the fork's own `main` in a repository that sends secrets to fork PRs.

Either one overwrites the default branch's engagement. The cleanup refuses `head == default_branch`,
but the import has no matching check.
**Fix:** pass `DD_DEFAULT_BRANCH: ${{ github.event.repository.default_branch }}` into dd-import. On
`pull_request`, when `branch == DD_DEFAULT_BRANCH`, print `SKIP`, write a results file with a skip
reason and exit 0, and let dd-verify accept that skip. Also add a head-repository equality check that
applies only to `pull_request`.

### WR-03: The concurrency group does not prevent the close-while-scanning race, and its comments misstate pending-job semantics (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1274-1279, 1655-1661`
**Issue:**

- **The group does not cover the race.** `defectdojo-import` joins the group only after its five
  `needs:` finish. A cleanup fired while those scans are still running therefore finds nothing to
  delete. The import then re-creates `ci/<branch>`, and nothing ever deletes it.
- **"Queued, never cancelled" is wrong.** GitHub cancels a *pending* job in the same group when a newer
  job joins. So a pending cleanup can be cancelled silently, and then `dd-cleanup-verify` never runs.

**Fix:** correct both comments. Just before the first POST, re-check the PR state through
`GET /repos/{repo}/pulls/{n}` with `pull-requests: read`, and skip the import if the PR is closed.
Alternatively, record the orphan case in a new ADR and add a periodic sweep of `ci/*` engagements.

### WR-04: One engagement per head-branch name is shared by every PR from that branch (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1452, 1805-1880`
**Issue:** Two open PRs from the same head (for example `hotfix` into `main` and `hotfix` into
`release/1.x`) share `ci/hotfix`. Each reimport closes the other PR's findings, and closing either PR
deletes the engagement while the other is still open. Long-lived non-default branches, such as
`develop` also imported through `workflow_dispatch`, are deleted on merge.
**Fix:** before deleting, list open PRs for the head
(`GET /repos/{repo}/pulls?state=open&head={owner}:{head}`) and refuse if any remain open. Or key PR
engagements as `ci/pr-<number>`. Add a `DEFECTDOJO_PROTECTED_BRANCHES` list.

### WR-05: The offline gate checks the side-channel `if:` and secret placement by substring (STILL OPEN)

**File:** `repos/security-platform/scripts/check-workflow-uploads.sh:412-453`
**Issue:**

- **Weak `if:` check.** SIDE-CHANNEL-SHAPE only checks that fragments are substrings of the job `if:`,
  so `always() || github.event.action != 'closed' && …` passes.
- **Missing cleanup term.** The cleanup's `github.event_name == 'pull_request'` term is not required.
- **No secret-scope check.** Nothing asserts that `secrets.DEFECTDOJO_API_TOKEN` appears only in the
  step env of dd-gate, dd-import and dd-delete, and never in `with:` or another step's env.
- **Wrong shell message.** The message at `:447` says the default shell is `bash -eo pipefail`.
  GitHub's default is `bash -e {0}`, without pipefail.

**Fix:** compare the normalized `if:` for exact equality, as SCAN-JOB-CLOSED-SKIP already does. Add a
SECRET-SCOPE check. Correct the shell wording.

### WR-06: The proof never exercises three irreversible-DELETE guards or the cleanup's insecure-TLS path (STILL OPEN)

**File:** `repos/security-platform/scripts/defectdojo-import-proof.sh` (cleanup cases); guards at `security.yml:1781-1783` (pagination), `:1838-1841` (duplicate product), `:1862-1864` (non-integer id)
**Issue:** The duplicate-product refusal, the paginated-response refusal, the non-integer-id refusal
and the dd-delete `::warning::` text are still never executed. P-HTTP added three assertions, but none
of them touches these guards. The count `PROOF PASS - 88 assertions` still overstates DELETE-guard
coverage.
**Fix:** add these cases:

- P-REFUSE-DUP;
- P-INSECURE-CLEANUP: `b_delete` with `DD_INSECURE=true` and an empty head ref, which refuses before
  any request, asserting the `::warning::` line;
- a localhost stub returning `"next": "x"` for the pagination guard.

### WR-07 (NEW): The SCHEME gate passes with the https refusal disabled, and does not check "every curl"

**File:** `repos/security-platform/scripts/check-workflow-uploads.sh:609-640` (and header `:43-45`)
**Issue:** SCHEME makes two checks. The literal `startswith("https://")` must occur somewhere in the
run body, and its *first* textual occurrence must come before the first `write_private(hdr_path`.
Neither check proves the refusal executes or exits.

This review copied the workflows to a scratch directory. It replaced both refusal lines with
`if False:  # url.lower().startswith("https://")` and ran `WORKFLOWS_DIR=<scratch> bash
scripts/check-workflow-uploads.sh`. The gate printed `PASS - 19 checks, 0 failures`. Replacing
`return 1` / `raise Failed()` with `pass` would pass for the same reason. This is the WR-05 weakness,
and the check's own comment says it was written to avoid it ("A presence-only substring check is the
WR-05 weakness").

Separately, the header says "every curl is pinned with --proto/--proto-redir", but the check only
requires each fragment to appear once per body. A second curl added without pins would pass. Today
each body has exactly one curl, so this matters only for future changes.

The actual behavioural guard is P-HTTP, and it has two enforcement gaps:

- **`--scheme-only` runs in no workflow.** `grep` finds no `.github/workflows` reference to it or to
  `check-workflow-uploads.sh`.
- **The live `--hook` run cannot block a merge.** It runs in `defectdojo-import-proof.yml`, which is
  path-filtered, is not a required check, and depends on the single-attempt `KIND-CELERY-PING` that
  ADR-025 item 6 records as flaky.

A regression therefore yields at most a red non-required check, never a blocked merge. The curl
`--proto =https` pin still prevents cleartext even if the Python refusal regresses, which is why this
is a Warning and not Critical.

**Fix:**

- Replace the substring test with an AST check. Parse the heredoc body with `ast`, find `main()`, and
  assert that its first statement is an `If` whose test is `not url.lower().startswith("https://")`
  and whose body ends in `Return(1)` (dd-import) or `Raise(Failed())` (dd-delete).
- For the pins, walk every `List` literal whose first element is `"curl"` and require the
  `--proto =https` and `--proto-redir =https` pairs in each.
- Also run `check-workflow-uploads.sh` and `defectdojo-import-proof.sh --scheme-only` in a cheap,
  unfiltered PR workflow. The latter needs only `jq`, `yq` and `python3`.

## Info

### IN-01: dd-delete step-5 "defence in depth" check is unreachable (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1850-1856`
**Issue:** `engagements` holds only rows named `ci/<head>`, and step 1 already refused
`head == default_branch`. The `protected` comparison can therefore never match.
**Fix:** remove it, or make it independent, for example by comparing `branch_tag`.

### IN-02: `always()` runs the import and proof jobs on cancelled runs (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1268`; `repos/security-platform/.github/workflows/defectdojo-import-proof.yml:83`
**Fix:** use `!cancelled() && …`.

### IN-03: dd-verify's message is misleading when the download fails (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1575-1577`
**Issue:** When `dd-download` fails, `dd-import` is skipped, but verify still says "see the FAILED
lines above" and there are none.
**Fix:** branch on `skipped` and print "import step did not run (artifact download failed?)".

### IN-04: The shared dd-gate says "import refused" / "import enabled" in the cleanup job (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1673, 1682`
**Fix:** change the wording to "DefectDojo side channel …" in both byte-identical copies.

### IN-05: `check-adoption-guide.sh` header is stale and DEFECTDOJO-SECTION needles are weak (STILL OPEN, partly improved)

**File:** `scripts/check-adoption-guide.sh:10-15, 270-275`
**Issue:** The header still says the contexts come from the job `name:` values. The needles
`"closed"`, `"reachable"` and `"secrets:"` match unrelated prose. The new `"must be https://"` needle
is specific and good. It is satisfied by the `FAILED: DEFECTDOJO_URL must be https://` sentence at
`docs/adoption-guide.md:764`.
**Fix:** update the header. Use specific needles such as the `types:` line and
`DEFECTDOJO_API_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }}`.

### IN-06: A whitespace-only product or product type is accepted (STILL OPEN)

**File:** `repos/security-platform/.github/workflows/security.yml:1387-1388, 1722`
**Fix:** apply `.strip()` and fail clearly when the value is empty.

### IN-07: The live-smoke post-hook runs any `DD_SMOKE_POST_HOOK` path with the admin password file exported (STILL OPEN)

**File:** `repos/security-platform/scripts/defectdojo-live-smoke.sh:758-768`
**Fix:** document that the variable must never come from untrusted input, or require the path to
resolve under `${REPO_ROOT}/scripts/`.

### IN-08 (NEW): The refusal message can print most of a URL that has no scheme; ADR-025's "never the URL" is overstated

**File:** `repos/security-platform/.github/workflows/security.yml:1427-1428, 1797-1798`; `docs/adr/adr025-defectdojo-import-https-only.md` Decision 1
**Issue:** The message prints `url.split("://", 1)[0]` whenever `"://"` appears anywhere in the URL.
For a URL with no scheme that contains `://` later, the check prints everything up to that point. This
review reproduced it: `defectdojo.internal:8080/api?x=https://y` prints
`'defectdojo.internal:8080/api?x=https'`. That exposes the internal host in the public log, and a URL
with embedded userinfo would expose that too.
**Fix:** use `urllib.parse.urlsplit(url).scheme` and print it only if it matches
`^[A-Za-z][A-Za-z0-9+.-]*$`, otherwise `(no scheme)`. Alternatively, qualify the ADR wording in a
later append-only record.

### IN-09 (NEW): Documentation drift after the fix, and one inaccurate ADR-025 claim

**File:** `docs/adr/adr025-defectdojo-import-https-only.md` "What was NOT verified" item 2; `docs/adoption-guide.md:807-817, 820+`; `repos/security-platform/.github/workflows/defectdojo-import-proof.yml:3-9`; `repos/security-platform/.github/workflows/security.yml:1352-1355`
**Issue:**

- **Inaccurate ADR claim.** ADR-025 says "no `-L` occurs in `security.yml` at `917352c`". The file
  contains `curl -sSfL` at `:425` (tflint) and `:1132` (gitleaks). The intended claim, that neither
  side-channel body passes `-L`, is true, but the literal statement is false.
- **Stale "Measured" subsection.** The adoption guide's "Measured" subsection still cites only the
  85-assertion runs, and says only that the known gaps are in ADR-024. It does not mention P-HTTP, the
  88-assertion runs, or that ADR-025 supersedes the TLS decision.
- **No troubleshooting entry.** Section 13 has no entry for the new `FAILED: DEFECTDOJO_URL must be
  https://` symptom.
- **Proof workflow header.** The header of `defectdojo-import-proof.yml` lists what the proof covers,
  and the non-https refusal is missing from that list.
- **dd-import comment block.** The comment above dd-import (`security.yml:1352-1355`) still says only
  "TLS is verified by default" and does not state the https-only refusal.

**Fix:** correct the ADR claim in a future append-only record; ADR-025 is Accepted. Update the guide's
"Measured" subsection and add a section 13 entry. Add the https refusal to both workflow comments.

### IN-10 (NEW): P-HTTP coverage gaps

**File:** `repos/security-platform/scripts/defectdojo-import-proof.sh:532-605`
**Issue:**

- **No uppercase-scheme case.** There is no positive case for an uppercase scheme
  (`HTTPS://…`, accepted). ADR-025 item 4 acknowledges this.
- **No delete-noscheme sub-case.** Only dd-import is tested with a URL that has no scheme.
- **"No request" is inferred, not observed.** It rests on the absence of an `http=` log line, because
  nothing listens on `127.0.0.1:9`, so a request that was sent could not be seen. That inference is
  sound for these bodies, since every request path logs `http=`, but the assertion text overstates what
  it measures.

**Fix:** add `delete-noscheme` and an `import-upper-https` case that expects no refusal line. Or, for
the "no request" claim, bind a one-shot listener on a free local port and assert that it received zero
connections.

---

_Reviewed: 2026-09-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
