# ADR-025: DefectDojo CI Import Refuses Non-HTTPS URLs

**Status:** Accepted
**Date:** 2026-09-25
**Addresses:** DDOJO-02 — `security-platform` CI scan jobs automatically import SARIF/JSON findings into
DefectDojo after each run — and code-review finding CR-01 (27-REVIEW, critical)

This record lives in this documentation repository. The public `security-platform` workflow
`security.yml` cites it by number in two comments, one above each refusal
(`# CR-01 / ADR-025: refuse a non-https URL before the TLS label, the token header and any request.`,
lines 1425 and 1795 at merge commit `917352c`), so a reader of the public repository cannot follow the
link. That is the same arrangement ADR-022, ADR-023 and ADR-024 recorded. Every measured value below is
quoted from a Phase 27 plan summary (27-11, 27-12, 27-13) or from a file in that phase's `evidence/`
directory, and each is attributed where it appears. No homelab address, hostname, token, product name or
DefectDojo instance URL appears here. The only hostnames are the RFC 2606 placeholder
`defectdojo.example.com` and the proof harness's loopback target `127.0.0.1:9` (RFC 1122 loopback, the
discard port), which never answers.

## Context

- **An `http://` URL was treated as verified TLS.** In the bodies merged by PR #21 (`0f7e4e1`),
  `dd-import` and `dd-delete` used `DEFECTDOJO_URL` as given, with no scheme check and no curl protocol
  restriction. With no TLS variable set, an `http://` URL fell into the same branch as a verified https
  URL: the log said `TLS mode: verified-system`, the results file recorded `"tls_mode":
  "verified-system"`, and `Authorization: Token <staff token>` went in cleartext on every import and every
  cleanup call (27-REVIEW CR-01). ADR-024's own tradeoff says that token is an instance-wide bypass:
  `is_staff` grants view, edit, add, import and delete across every product on the instance. So the worse
  mode got no warning and a false assertion in the log.
- **Neither the gate nor the proof could catch it.** `check-workflow-uploads.sh` INSECURE-WARNING only
  checked that the literals `DD_INSECURE` and `::warning::` appear somewhere in the body. The proof
  harness only ever used https URLs, so the http path was never executed (27-VERIFICATION truth 13,
  PARTIAL). 27-11 reproduced the defect before fixing it: the unfixed body, given
  `DD_URL=http://127.0.0.1:9`, printed `TLS mode: verified-system` and made real curl attempts, and
  `defectdojo-import-proof.sh --scheme-only` ended `PROOF FAIL - 3 of 3` (27-11-SUMMARY, RED evidence).
- **It mattered before Phase 29.** A plain-http URL is a realistic misconfiguration for the instance
  Phase 29 has to reach, through a tunnel or an internal service URL (27-REVIEW CR-01). The
  verification did not allow it to be deferred to Phase 28 or 29.
- **ADR-024 may not be edited.** `docs/adr/` is append-only per `CLAUDE.md`. ADR-024 decision 13 says
  "TLS verified by default" and names `DEFECTDOJO_INSECURE` as the only warned-about weaker mode; its
  decision 15 records the offline gate at 18 checks. Both are now out of date. The repository precedent
  for changing an accepted decision is a new record that supersedes the old one in prose (ADR-021 over
  ADR-020), and 27-VERIFICATION's last `missing:` item asks for exactly this: "Record the fix ... in
  ADR-024 via an append — new dated entry or ADR-025, not an edit to the Accepted body".

## Decision

This record supersedes ADR-024 decision 13 **in prose** for non-https URLs, and records the gate count
that ADR-024 decision 15 gives as 18 as now 19. ADR-024 is untouched. For https URLs, ADR-024
decision 13 stands as written: verified by default, `DEFECTDOJO_CA_CERT` for a private CA,
`DEFECTDOJO_INSECURE=true` only with a warning.

1. **Scheme refusal is the first statement of `main()` in both bodies.** `dd-import` and `dd-delete`
   check `url.lower().startswith("https://")`, so the comparison is case-insensitive. On any other
   scheme, or a URL with no scheme, they print
   `FAILED: DEFECTDOJO_URL must be https:// — refusing to send the API token over 'http'` (or
   `'(no scheme)'`). Only the scheme is printed, never the URL. `dd-import` returns 1; `dd-delete` raises
   `Failed()`. The refusal runs before the TLS label, before the token header file is written and before
   any request. 27-11 measured the line order in `security.yml`: dd-import refusal L1426 <
   `TLS mode:` L1443 < `write_private(hdr_path` L1456; dd-delete refusal L1796 < `TLS mode:` L1825 <
   `write_private(hdr_path` L1828. In `dd-delete` the scheme check also runs before the default-branch
   refusals, so a misconfigured URL fails loudly even on a run that would have been refused anyway
   (27-11 decision).
2. **Every curl call is pinned to https.** Both bodies build curl with
   `--proto =https --proto-redir =https`. On `origin/main` each of `url.lower().startswith("https://")`
   and `"--proto-redir", "=https"` occurs 2 times in `security.yml` (27-12, read after the merge).
3. **No opt-out.** There is no variable that allows http. `DEFECTDOJO_INSECURE=true` still only
   disables certificate verification on an https URL. The operator accepted this at the merge gate
   (27-12 decision a: an http:// or scheme-less URL fails the non-required import and cleanup jobs red,
   with no token sent, and there is no opt-out).
4. **A SCHEME check in the offline gate, with an ordering assertion.** `check-workflow-uploads.sh` gained
   a 19th check, SCHEME. It asserts the refusal fragment and both curl pins are present in each body, and
   that the refusal precedes the header write, so a refusal moved below `write_private(hdr_path` fails.
   Before the fix it failed 8 times (27-11 RED); after it the gate printed
   `PASS - 19 checks, 0 failures`, and `origin/main` carries `CHECK_COUNT = 19` (27-12). 27-11's scratch
   negative self-tests showed that removing the dd-delete refusal, or moving the dd-import refusal below
   the header write, each fail SCHEME for that job only.
5. **A P-HTTP proof case that runs the committed bodies.** `defectdojo-import-proof.sh` extracts the
   committed bodies and runs three sub-cases: `import-http` (`DD_URL=http://127.0.0.1:9`),
   `import-noscheme` (`DD_URL=127.0.0.1:9`) and `delete-http`. Each asserts exit 1, the refusal printed
   before any TLS label, no request, no results file and the token absent from the log. It runs live in
   the kind post-hook (`--hook`) and offline with `--scheme-only` (27-11: `PROOF PASS - 3 assertions`).
6. **Released as the patch `v1.1.1`, with `v1` moved (ADR-018).** A security fix with no interface
   change is a patch. 27-13 created the annotated tag `v1.1.1` (tag object
   `c1565b35e88de4e70e61d79292943c15b3fe67f6` → `917352c00987023fa5ff1e6cdabc16987eb114dd`) and moved
   the lightweight `v1` from `0f7e4e141d2a300d4be9a54efc137eb4510bb7ea` to `917352c…` with
   `--force-with-lease` pinned to the pre-checked remote value. `v1.1.0`, `v1.0.0` and `v2.0` were not
   touched.

### Measured evidence

- **Merge (27-12):** PR #22 merged with `gh pr merge 22 --merge` as the two-parent merge commit
  `917352c00987023fa5ff1e6cdabc16987eb114dd` (parents `0f7e4e1…`, the prior main, and
  `ba3683aae86fefdfc004f158c6022a0ef38da5fe`, the fix). `scripts/set-required-checks.sh` has shasum
  `aa71d79a9fd700abdff469d7c8101e240e969400` on both `origin/main` and `0f7e4e1`, so the required
  contexts did not change.
- **PR proof on GitHub (27-12):** DefectDojo Import Proof run 36186258881. Attempt 1 failed at
  `KIND-CELERY-PING` before any proof case ran. The operator approved one rerun, and attempt 2
  (prove-import job 108243485918) passed with the three `PROOF: P-HTTP PASS` lines and
  `PROOF PASS - 88 assertions` (`evidence/27-12-proof-run.log`). PR checks: 18 pass, 4 skipped; the
  five required contexts passed and both DefectDojo jobs skipped (`evidence/27-12-pr-checks.txt`).
- **Proof on `main` by dispatch (27-13):** run 36188604648, attempt 1, head `917352c`, prove-import job
  108248236695: `KIND-CELERY-PING: PASS`, `ALL PASS - 13 live check(s)`, P-HTTP PASS for import-http,
  import-noscheme and delete-http, `PROOF PASS - 88 assertions` (`evidence/27-13-post-merge.txt`).
- **Tag readbacks (27-13):** `refs/tags/v1.1.1` has `object.type` tag, tag object `c1565b3…`, which
  peels to `917352c…`; `refs/tags/v1` has `object.type` commit at `917352c…`. Unchanged: `v1.1.0`
  `414fd3b` → `0f7e4e1`, `v1.0.0` `fabc3e3` → `cdf2c21`, `v2.0` `8d47cf9` → `c6395e1`. The raw `/v1/`
  `security.yml` contains `url.lower().startswith("https://")` 2 times.
- **Release (27-13):** `v1.1.1`, not a draft or prerelease, published 2026-09-26T02:10:39Z,
  <https://github.com/OttawaCloudConsulting/security-platform/releases/tag/v1.1.1>.

## Consequences

**Improved:** the staff token can no longer leave the runner in cleartext through this job, whatever
`DEFECTDOJO_URL` says, and the log can no longer claim `verified-system` for a connection with no TLS.

**Tradeoff — http consumers turn red.** A consumer on `@v1` or `v1.1.1` whose `DEFECTDOJO_URL` is
`http://…` or has no scheme gets red `security / DefectDojo Import` and `security / DefectDojo Cleanup`
jobs on the next run, with no token sent. Neither job is required, so nothing is blocked, but findings
stop arriving until the URL is changed to https. The adoption guide's section 12 now states the
requirement, and `check-adoption-guide.sh` DEFECTDOJO-SECTION requires the phrase `must be https://`
so the statement cannot silently disappear.

**Tradeoff — the refusal outranks the cleanup's default-branch refusal.** A closed PR in a repository
with an http URL fails `dd-delete` on the scheme first, not on the branch guard. The outcome is the same
(no request), but the failure message is the scheme one.

**Changed count — the proof moved from 85 to 88 assertions.** The three P-HTTP sub-cases are the only
additions (27-12 decision). ADR-024's "85-assertion proof" remains an accurate record of what was
measured then.

**Hand-forward — Phase 29.** Whatever route Phase 29 picks to reach the real instance, it must present
https to the runner. A plain-http internal URL is no longer an option for this job.

## What was NOT verified

What WAS measured and must not be re-litigated: the 8 SCHEME failures before the fix and the 19-check
pass after it (27-11); the three P-HTTP cases failing against the unfixed body and passing against the
fixed one, offline (27-11) and live on GitHub (36186258881 attempt 2, 36188604648); the merged tree on
`origin/main` (27-12); and the tag and release readbacks (27-13).

1. **No real consumer with an http:// URL has been observed failing.** No consumer, and not
   `security-platform` itself, sets `DEFECTDOJO_URL` (ADR-024 item 6 still holds). The red-job
   consequence above comes from the proof harness, not from a consumer run.
2. **`--proto-redir` is defence in depth only.** Neither body passes `-L` (no `-L` occurs in
   `security.yml` at `917352c`), so curl never follows a redirect and no redirect was exercised.
   `--proto =https` is what stops a non-https request; `--proto-redir` only matters if a future change
   adds redirect following.
3. **Only the scheme is inspected.** An https URL that points at an unintended host is not detected;
   the token goes wherever an https `DEFECTDOJO_URL` names, verified against the runner's trust store
   or `DEFECTDOJO_CA_CERT`.
4. **Case-insensitivity was spot-checked locally only.** 27-11 ran the extracted fixed dd-import body
   with `DD_URL=HTTPS://127.0.0.1:9` and it was accepted. No P-HTTP sub-case covers an upper-case
   scheme, and it was not exercised on GitHub.
5. **The remaining 27-REVIEW warnings are out of scope and unaddressed.** WR-01 (`close_old_findings`
   on errored scans), WR-02 (no default-branch or foreign-head guard on import), WR-03 (concurrency
   group and the close-while-scanning race), WR-04 (one engagement per head-branch name), WR-05
   (substring-based gate checks) and WR-06 (DELETE guards and the cleanup's insecure path not proven)
   were not changed by this fix.
6. **`KIND-CELERY-PING` is still a single attempt.** It flaked on run 36186258881 attempt 1 (27-12) as
   it had on 36159160216 (27-08). The bounded-retry follow-up is still open (27-12 and 27-13 Deferred).
7. **The release body was not written by the planned command.** The executor's `gh release create` was
   denied by the permission system; the orchestrator created the release with the operator's
   authorization, using `--notes-file` rather than inline `--notes`. The published body was scanned and
   contained 0 local paths (27-13 deviations 1 and 2).
