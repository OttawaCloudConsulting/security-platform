---
phase: 27-defectdojo-ci-auto-import
reviewed: 2026-09-25T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - repos/security-platform/.github/workflows/defectdojo-import-proof.yml
  - repos/security-platform/.github/workflows/pr-security.yml
  - repos/security-platform/.github/workflows/scheduled-security.yml
  - repos/security-platform/.github/workflows/security.yml
  - repos/security-platform/scripts/check-workflow-uploads.sh
  - repos/security-platform/scripts/defectdojo-import-proof.sh
  - repos/security-platform/scripts/defectdojo-live-smoke.sh
  - scripts/check-adoption-guide.sh
findings:
  critical: 1
  warning: 6
  info: 7
  total: 14
status: issues_found
---

# Phase 27: Code Review Report

**Reviewed:** 2026-09-25
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Scope: the Phase 27 diff of `repos/security-platform` (`71a112e..0f7e4e1`). In `security.yml` that means
the `defectdojo-import` and `defectdojo-cleanup` jobs, the closed-skip `if:` on the five scan jobs, and the
optional `workflow_call` secret. The review also covers the two callers, the proof workflow, the proof
harness, the live-smoke post-hook, `check-workflow-uploads.sh`, and the Phase 27 changes to
`scripts/check-adoption-guide.sh` (commits `a58427c` and `72f47de`).

The priority concerns held up:

- **Script injection:** no side-channel `run:` body contains `${{ }}`. Attacker-controlled values arrive
  only through step `env:` or `GITHUB_*`, and `--form-string` keeps a leading `@` in a branch name
  literal.
- **Token handling:** the token is sent from a 0600 header file with `-H @file`, never on an argv, never
  echoed, and never placed in job-level env.
- **Trigger and permissions:** every trigger is `pull_request`, never `pull_request_target`, and the job
  permissions are minimal.
- **Delete guards:** the `dd-delete` product and engagement guards are correct as written. They are a
  product `name_exact` lookup plus a client-side `==`, a refusal when more than one product matches or the
  response is paginated, an engagement `==` plus a product-id re-check, and a default-branch refusal
  before any request.

The defects are in what surrounds those guards:

- **Cleartext transport:** the "TLS verified by default" claim (D-18) is false for an `http://`
  `DEFECTDOJO_URL`, and the job still logs `TLS mode: verified-system`.
- **Unchecked reports:** the import closes old findings based on report files whose producing scan step
  may have errored.
- **Branch-name keying:** the per-branch engagement key collides across PRs, and the import job has no
  default-branch guard to match the cleanup job's.
- **Race:** the concurrency group does not cover the close-while-scanning race it was added for, and its
  comment misstates GitHub's pending-job semantics.
- **Weak gate:** the offline gate checks the side-channel `if:` expressions by substring, so it can pass
  a broken expression.

Operator decisions a–g and the ADR-024 "What was NOT verified" items are not re-reported. Where a finding
touches one of them (WR-03 touches A3), the finding covers a case the ADR does not record.

## Critical Issues

### CR-01: A plain-HTTP `DEFECTDOJO_URL` sends the instance-wide staff token in cleartext and logs `TLS mode: verified-system`

**File:** `repos/security-platform/.github/workflows/security.yml:1384, 1425-1438, 1494-1498` (dd-import) and `:1716, 1802-1815, 1753-1754` (dd-delete)
**Issue:** `url = env.get("DD_URL", "").rstrip("/")` is used as-is. There is no scheme check and no
`--proto`/`--proto-redir` restriction. When `DEFECTDOJO_URL` is `http://…`, the empty-`tls_args` branch
sets `tls_mode = "verified-system"` and prints `TLS mode: verified-system`. It then sends
`Authorization: Token <staff token>` in cleartext on every import and every cleanup, and writes
`"tls_mode": "verified-system"` into `dd-import-results.json`.

ADR-024 D-18 says "TLS verified by default", and the only `::warning::` exists for
`DEFECTDOJO_INSECURE=true`. The worse mode therefore gets no warning and a false positive assertion in
the log. Per ADR-024's own tradeoff, this token is a full-instance write/delete credential. A plain-HTTP
URL is a realistic misconfiguration for the homelab instance that Phase 29 has to reach (tunnel or
internal service URL). `check-workflow-uploads.sh` INSECURE-WARNING only checks that the literal
`DD_INSECURE` and `::warning::` appear somewhere in the body, so it cannot catch this.

**Fix:** refuse non-HTTPS before writing the header file, in both bodies, and pin curl's protocols:

```python
if not url.lower().startswith("https://"):
    print("FAILED: DEFECTDOJO_URL must be https:// — refusing to send the API token over {!r}".format(
        url.split("://", 1)[0] if "://" in url else "(no scheme)"))
    return 1          # dd-delete: raise Failed()
...
cmd = ["curl", "-sS", "--proto", "=https", "--proto-redir", "=https", ...]
```

Also add a SCHEME check to `check-workflow-uploads.sh` that looks for the `https://` refusal in both
bodies, and add a P-HTTP case to the proof that asserts exit 1 and that no request is made.

## Warnings

### WR-01: `close_old_findings=true` is applied to reports whose scan step errored, so a broken scanner run can close every open finding in its Test

**File:** `repos/security-platform/.github/workflows/security.yml:1285, 1463-1498` (job `if: always()`, and the import loop with `close_old_findings=true` at `:1487`)
**Issue:** The import job runs under `always()` and imports every report file that exists. It never
checks whether the scan step that produced the file succeeded or whether the report is a valid, complete
scan.

The scan jobs upload artifacts under `if: always()` (for example `:118-125`, `:199-201`, `:865-867`). A
scanner that exits non-zero because of an error and still writes a well-formed report with no findings
is indistinguishable from a clean scan. Semgrep is the likely example: a failed `p/default` registry
fetch can produce a JSON with `errors` populated and `results: []`. Because the import sends
`close_old_findings=true`, DefectDojo then mitigates every open finding in that Test and `dd-verify`
reports green (HTTP 201 with a `test_id`).

The workflow already knows this failure class exists. The `Verify npm audit reports` step (`:652-672`)
exists because npm's error object is indistinguishable by exit code, but the import ignores that
verify step's result. The next good run reactivates the findings on reimport. In between, DefectDojo
shows false "fixed" status and wrong mitigation dates, and a security dashboard shows no open findings
for a scanner that did not run. Not reproduced live; the gap in the code path is certain, while which
scanners actually emit a valid empty report on error is unverified.

**Fix:** have each scan job's report-content verify step (or a new one) write a per-report
`<file>.ok` marker into the artifact only when the report is structurally valid and the scanner did not
report an error. Then either import only files that have their marker, or send
`close_old_findings=false` for any file without one. At minimum, skip a Semgrep report whose `errors`
array is non-empty:

```python
if name == "semgrep-results.json":
    with open(path, encoding="utf-8") as fh:
        if (json.load(fh).get("errors") or []):
            fields = [f for f in fields if not f.startswith("close_old_findings=")] + ["close_old_findings=false"]
```

Also use `!cancelled()` instead of `always()` on the job (see IN-02).

### WR-02: The import has no default-branch or foreign-head guard, so a PR can overwrite and close findings in `ci/<default>`

**File:** `repos/security-platform/.github/workflows/security.yml:1440-1447`
**Issue:** On `pull_request` the engagement is always `"ci/" + GITHUB_HEAD_REF`. The cleanup refuses
`head == default_branch`, but the import has no equivalent guard. The reimport sends
`close_old_findings=true`, so either of these PRs replaces the default-branch engagement's findings with
the PR's own scan results and closes the rest:

- A same-repo PR whose head is the default branch (for example `main` into `release/x`, a normal
  back-merge) imports the `refs/pull/N/merge` scan into `ci/main`.
- When a repository enables "send secrets to workflows from fork pull requests" (private repos), a fork
  PR from the fork's own `main` has `GITHUB_HEAD_REF=main`. More generally, a fork PR from any branch
  name that also exists in the base repository imports into that engagement.

The `head.repo` guard was rejected (D-13) because it is null on `schedule`. The fix below keeps
schedule working and adds the missing guard.

**Fix:** in dd-import, on `pull_request`:

```python
if env.get("GITHUB_EVENT_NAME") == "pull_request":
    branch = env.get("GITHUB_HEAD_REF", "")
    if branch == env.get("DD_DEFAULT_BRANCH", ""):
        print("SKIP: PR head is the default branch — ci/{} is owned by the scheduled run".format(branch))
        ...write results with attempted=[] and a skip reason, exit 0, and let dd-verify accept it...
```

Pass `DD_DEFAULT_BRANCH: ${{ github.event.repository.default_branch }}` in step env, as dd-delete does.
Add a `DD_HEAD_REPO` / `GITHUB_REPOSITORY` equality check that applies only when
`GITHUB_EVENT_NAME == 'pull_request'`, and extend the proof CONTRACT and cases.

### WR-03: The concurrency group does not prevent the close-while-scanning race, and its comment misstates GitHub's pending-job semantics

**File:** `repos/security-platform/.github/workflows/security.yml:1293-1299, 1651-1656`
**Issue:** The comments say "Queued, never cancelled: an in-flight import is allowed to finish" and "an
import still running from the final push finishes BEFORE this delete starts". Two problems:

1. `defectdojo-import` has `needs:` on all five scans, so it does not enter the concurrency group until
   those scans finish. If a PR is closed (abandoned, or admin-merged) while the final push's scans are
   still running, `defectdojo-cleanup` has no `needs:`. It enters the empty group at once, deletes or
   finds nothing to delete, and exits. The final import then re-creates `ci/<branch>`, and nothing ever
   deletes it. This is Pitfall 9, the race the group exists to stop, and the group does not cover this
   ordering. ADR-024 "not verified" item 3 only records that the serialization was assumed. It does not
   record this ordering gap.
2. GitHub's documented behaviour is that when a job joins a group, any job already pending in that group
   is cancelled. With `cancel-in-progress: false`, only the running job is protected. A pending
   `defectdojo-cleanup` is therefore cancelled by a later import in the same group, for example after a
   quick reopen and push. When that happens, `dd-cleanup-verify` never runs to turn it red. "Never
   cancelled" is incorrect.

**Fix:**

- Correct both comments to state the pending-replacement semantics.
- Make the import re-check PR state right before the first POST: on `pull_request`, call
  `GET /repos/{repo}/pulls/{n}` with `GITHUB_TOKEN` (`pull-requests: read`) and skip the import when
  `state == closed`.
- Otherwise, document the orphan case in ADR-024's known gaps and add a periodic sweep of `ci/*`
  engagements whose branch no longer has an open PR.

### WR-04: One engagement per head-branch name is shared by every PR from that branch, so closing one PR deletes another open PR's findings

**File:** `repos/security-platform/.github/workflows/security.yml:1447, 1800-1857`
**Issue:** The engagement key is `ci/<head_ref>` only. Two open PRs from the same head, for example
`hotfix` into `main` and `hotfix` into `release/1.x`, write to the same engagement, and each reimport
closes the other's findings through `close_old_findings`. When either PR closes, `dd-delete` deletes the
engagement while the other PR is still open.

The same applies to long-lived non-default branches (`develop`, `release/*`) that also get
`workflow_dispatch` imports through `scheduled-security.yml`. Merging `develop` into `main` deletes
`ci/develop`. Only the default branch is protected (`:1795`, `:1842`).

**Fix:** before deleting, list open PRs for the head:
`GET /repos/{repo}/pulls?state=open&head={owner}:{head}` with `GITHUB_TOKEN` and
`pull-requests: read`. If any are still open, return `finish("refused", ...)`. Also add a
`DEFECTDOJO_PROTECTED_BRANCHES` variable (newline list), checked alongside `default_branch`.
Alternatively, key PR engagements as `ci/pr-<number>`, and document which option was chosen in ADR-024.

### WR-05: The offline gate checks side-channel `if:` and secret placement by substring, so it passes broken or leaking shapes

**File:** `repos/security-platform/scripts/check-workflow-uploads.sh:410-444, 464-474`
**Issue:**

- SIDE-CHANNEL-SHAPE (`:429-432`) only asserts that each fragment is a substring of the job `if:`. The
  expression `always() || github.event.action != 'closed' && vars.DEFECTDOJO_URL != ''` passes, and it
  runs the import on closed events. Prefixing `!(...)` passes too.
- The cleanup's `github.event_name == 'pull_request'` term is not required at all (`:412`). Dropping it
  would run cleanup (a DELETE) on any `closed` action from another caller event type, for example an
  `issues: closed` caller, where `GITHUB_HEAD_REF` is empty. That case would be refused, so the impact is
  limited, but it is exactly the kind of drift the gate claims to catch.
- Nothing asserts that `secrets.DEFECTDOJO_API_TOKEN` appears only in the step env of
  `dd-gate`/`dd-import`/`dd-delete`. Passing it in the `with:` or `env:` of the third-party
  `dd-download` action, or in another step's env, passes every check. The job-env check (`:433-438`) does
  not cover this.
- The message at `:444` says the default shell is "bash -eo pipefail". For a `run:` with no `shell:`,
  GitHub runs `bash -e {0}` without pipefail. The proof harness (`defectdojo-import-proof.sh:210-213`,
  `:399`) correctly uses `bash -e`.

**Fix:** compare the normalized `if:` for exact equality with the committed string, the way
SCAN-JOB-CLOSED-SKIP already does (`:535-538`). Add a SECRET-SCOPE check: for every step in every
workflow, `secrets.DEFECTDOJO_API_TOKEN` may appear only in `env.DD_TOKEN` of steps whose id is
`dd-gate`, `dd-import` or `dd-delete`, and never in `with:`. Fix the shell message.

### WR-06: The proof never exercises three of the irreversible-DELETE guards or the cleanup's insecure-TLS path

**File:** `repos/security-platform/scripts/defectdojo-import-proof.sh:1187-1337`
**Issue:** The DELETE path is the one irreversible operation in the phase. The proof covers only the
happy delete, the product scope, the empty-head and default-branch refusals, and no-match. These cases
are never executed:

- the "two products exactly named" refusal (`security.yml:1828-1831`);
- the paginated-response refusal (`:1776-1778`);
- the non-integer id refusal (`:1852-1854`);
- the `dd-delete` insecure-TLS warning, whose wording differs from the import's. P-INSECURE runs only
  `b_import`.

`CHECK_COUNT`/`PROOF PASS - 85 assertions` therefore overstates guard coverage. The product-duplicate
case cannot be created through the UI with the same case, but it can with differing case, and the
client-side `==` is what should then prevent a wrong delete. That path is also unexercised.

**Fix:** add P-REFUSE-DUP (create `proof/Security-Platform` beside `proof/security-platform` and assert
that exactly one is resolved, or that the refusal fires on a true duplicate created through the admin
ORM). Add P-INSECURE-CLEANUP (run `b_delete` with `DD_INSECURE=true`, `DD_URL=https://127.0.0.1:9` and
an empty head ref, so it refuses before any request, and assert the `::warning::` line). The pagination
guard can be covered with a stub HTTP server on localhost that returns `"next": "x"`.

## Info

### IN-01: The step-5 "defence in depth" check in dd-delete is unreachable

**File:** `repos/security-platform/.github/workflows/security.yml:1840-1846`
**Issue:** `engagements` already holds only rows where `name == target == "ci/" + head`, and step 1
returned early when `head == default_branch`. The condition `e.get("name") == "ci/" + default_branch` can
therefore never be true. The comment presents this as an independent second guard. It is not one.
**Fix:** delete it, or make it independent. For example, compare the resolved engagement's `branch_tag`,
or compare against the engagement created by the scheduled run.

### IN-02: `always()` makes the import and proof jobs run on cancelled runs

**File:** `repos/security-platform/.github/workflows/security.yml:1285`; `repos/security-platform/.github/workflows/defectdojo-import-proof.yml:83`
**Issue:** `always()` also fires when the run was cancelled. A superseded PR run still imports whatever
partial artifacts exist (see WR-01), and the proof starts a 60-minute kind job after a cancel.
**Fix:** use `!cancelled() && …` in both places. That still runs after a failing blocking gate, which is
what the comments are after.

### IN-03: dd-verify's message is misleading when the download step fails

**File:** `repos/security-platform/.github/workflows/security.yml:1570-1572`
**Issue:** If `dd-download` fails, `dd-import`'s implicit `success()` skips it. The outcome is then
`skipped`, and verify prints "at least one report did not land … see the FAILED lines above", but there
are no FAILED lines.
**Fix:** branch on `skipped` and print "import step did not run (artifact download failed?)".

### IN-04: The shared dd-gate message says "import refused" in the cleanup job

**File:** `repos/security-platform/.github/workflows/security.yml:1668, 1677`
**Issue:** The byte-identical gate prints "DefectDojo import refused" and "import enabled" during
cleanup, which misleads anyone reading a cleanup log. DD-GATE-IDENTICAL enforces the duplication.
**Fix:** change the text to "DefectDojo side channel refused/enabled" in both copies.

### IN-05: check-adoption-guide.sh header is stale and DEFECTDOJO-SECTION needles are weak

**File:** `scripts/check-adoption-guide.sh:10-15, 270-274`
**Issue:** The header still says the contexts come from the five `name:` values on security.yml's jobs.
Since `a58427c` they come from the scan-job ids. The needles `"closed"`, `"reachable"` and `"secrets:"`
are satisfied by unrelated prose ("disclosed", "unreachable") or by any YAML snippet, so the check cannot
tell whether the Mode B caller instructions (the `types:` list and the `secrets:` pass) are actually
present.
**Fix:** update the header. Use specific needles such as `types: [opened, synchronize, reopened, closed]`
and `DEFECTDOJO_API_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }}`.

### IN-06: Unset or blank `DEFECTDOJO_PRODUCT_TYPE` handling depends on expression falsiness only

**File:** `repos/security-platform/.github/workflows/security.yml:1367-1368, 1387-1388, 1701, 1717`
**Issue:** A whitespace-only variable (`" "`) is truthy, so the product type (or the product) becomes a
single space and the import creates a Product Type named `" "`. The cleanup then looks up product `" "`.
**Fix:** `product = env.get("DD_PRODUCT", "").strip()`, and fail with a clear message if it is empty
after stripping. Do the same for the product type.

### IN-07: The live-smoke post-hook runs any path in `DD_SMOKE_POST_HOOK` with the admin password file exported

**File:** `repos/security-platform/scripts/defectdojo-live-smoke.sh:758-768`
**Issue:** The hook is an arbitrary environment-selected script, and it inherits `DD_ADMIN_PW_FILE`.
This is harmless in the current callers. It is worth a comment that the variable must never be set from
untrusted input (for example a workflow `env:` fed by `inputs`).
**Fix:** document it, or require that the hook path resolve inside `${REPO_ROOT}/scripts/`.

---

_Reviewed: 2026-09-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
