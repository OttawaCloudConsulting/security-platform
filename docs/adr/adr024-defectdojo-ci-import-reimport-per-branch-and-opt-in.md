# ADR-024: DefectDojo CI Import — Reimport per Branch, Delete on Close, Opt-In

**Status:** Accepted
**Date:** 2026-09-25
**Addresses:** DDOJO-02 — `security-platform` CI scan jobs automatically import SARIF/JSON findings into
DefectDojo after each run

This record lives in this documentation repository. The public `security-platform` workflow headers
(`security.yml`, `pr-security.yml`, `scheduled-security.yml`) and `scripts/check-workflow-uploads.sh` cite it
by number since PR #21 (merge commit `0f7e4e1`), so a reader of the public repository cannot follow the
link. That is the same arrangement ADR-022 and ADR-023 recorded. Writing this record is itself Phase 27
decision D-22. Every measured value below is quoted from
a Phase 27 plan summary (27-01 to 27-09), from a file in that phase's `evidence/` directory, or from a
statement 27-RESEARCH marks as verified against DefectDojo 3.3.200 source; each is attributed where it
appears. No homelab address, hostname, token, product name or DefectDojo instance URL appears here. The
only hostnames are the RFC 2606 placeholder `defectdojo.example.com` and the proof harness's throwaway
`.invalid` / `.test` names.

## Context

- **DefectDojo existed but nothing fed it.** ADR-023 put a DefectDojo 3.3.200 chart in
  `kubernetes/defectdojo/`. The five scan jobs in `security.yml` already kept their native reports as
  `*-results` artifacts (the CICD-03 retention contract: "normalising would destroy import fidelity"), but no
  job sent them anywhere.
- **The five required contexts are frozen.** ADR-017 and ADR-019 made `security / SAST — Semgrep CE`,
  `security / IaC — Checkov`, `security / SCA — Trivy Filesystem`, `security / Container — Trivy Image` and
  `security / Secrets — Gitleaks` the required checks, enforced by `scripts/set-required-checks.sh`. Any new
  job that became required, or that renamed or reordered a scan job, would break every consumer's ruleset.
- **ADR-018 froze the packaging.** Consumers call `security.yml` by copy (Mode A) or by `workflow_call` at
  `@v1` (Mode B). Mode A copies three files and has no `scripts/` tree, so any design that runs a script
  from the callee breaks it (27-RESEARCH Pitfall 7). A breaking change would need `v2`.
- **One reimport call covers first and later runs.** At 3.3.200, `POST /api/v2/reimport-scan/` with
  `auto_create_context=true` creates the Product Type, Product, Engagement and Test when none match, and
  otherwise updates the Test in place (27-RESEARCH). In-place matching does not depend on the global
  `enable_deduplication` switch, which defaults to off.
- **Open-source authorization changed in 3.x.** The Reader/Writer/Maintainer/Owner/API_Importer roles are
  inert in the open-source build. Engagement delete and creating a new Product Type require `is_staff`
  (27-RESEARCH, authorization section). A non-superuser staff user is the smallest identity that can
  import, auto-create and delete with one token.
- **Two report types share a parser.** `trivy-fs.json` and `trivy-image.json` both use `scan_type`
  `Trivy Scan`. Without an explicit `test_title`, reimport takes the last Test of that scan type, so the two
  would overwrite each other (27-RESEARCH).
- **This record extends five accepted decisions rather than editing any of them.** ADR-001 (the
  `continue-on-error` carve-out for side-channel uploads), ADR-004 (SHA-pinned actions), ADR-017 (gate mode
  and required checks), ADR-018 (packaging and versioning) and ADR-023 (the chart the proof runs) are cited
  here. None of those files was edited.

## Decision

1. **One `defectdojo-import` job, after the five scans, under `always()` (D-01).** It `needs:` `sast`,
   `iac`, `sca`, `container` and `secrets`, and its `if:` is
   `always() && github.event.action != 'closed' && vars.DEFECTDOJO_URL != ''` (read from `security.yml` at
   `0f7e4e1`). It downloads that run's own `*-results` artifacts with `actions/download-artifact` pinned to
   `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` (v8.0.1, 27-02; ADR-004). The five scan jobs keep their ids,
   names and order, and stay needs-free.
2. **Opt-in through `DEFECTDOJO_URL` plus a token-presence gate, not the `head.repo` guard (D-02, D-13).**
   The job-level `if:` checks the variable. A `dd-gate` step then writes only a boolean to `GITHUB_OUTPUT`:
   `enabled=false` with a SKIP line when the token is empty (fork runs, and any caller that passes no
   secret) or when the actor is `dependabot[bot]`. The existing verify steps' pull-request-shaped guard
   (`github.event.pull_request.head.repo.full_name == github.repository`) was not reused, because it is null
   on `schedule` and the import would silently never run there (27-RESEARCH Pitfall 3). A repository that
   sets nothing behaves as before.
3. **`continue-on-error` import plus a red verify, never a required check (D-03, ADR-001).** `dd-import` is
   `continue-on-error: true`; `dd-verify` reads `steps.dd-import.outcome` through its step env and fails
   red when an import did not land, when the results file is missing, or when nothing was attempted
   ("NOTHING IMPORTED is not a pass"). `scripts/set-required-checks.sh` is byte-identical before and after
   the phase (shasum `aa71d79a9fd700abdff469d7c8101e240e969400` on both `71a112e` and `0f7e4e1`, 27-07), so
   DefectDojo availability can never block a merge.
4. **Plain `curl` driven by inline `python3`, no marketplace action (D-04).** One `curl` call per report
   file. Every non-file field goes through `--form-string`, so a branch name beginning with `@` is sent
   literally and never read as a file (27-02 mock case `@/etc/passwd`). The token is sent from a 0600
   header file (`-H @file`), never on an argv. A curl-level failure is recorded as `http_code 000` and
   fails verify.
5. **Naming (D-05, D-06, D-07).** Product name is `DEFECTDOJO_PRODUCT` or, when unset, `github.repository`.
   Product Type is `DEFECTDOJO_PRODUCT_TYPE` or the default `CI` (operator decision a at the PR #21 merge,
   27-07). Each branch gets its own engagement, `ci/<branch>`: the PR head branch on a pull request, the
   default branch on a schedule. Each report file is one Test.
6. **Native parsers, with tflint as SARIF (D-08).** The fixed import table in `dd-import` is: `Semgrep JSON
   Report` (`semgrep`), `Checkov Scan` (`checkov`), `Trivy Scan` (`trivy-fs` and `trivy-image`),
   `Gitleaks Scan` (`gitleaks`), `NPM Audit v7+ Scan` (`npm-audit-N`), `pip-audit Scan` (`pip-audit-N`) and
   `SARIF` (`tflint`). The `TFLint Scan` parser exists at 3.3.200 but reads JSON only; using it would mean
   changing the `sca` scan job's output, which D-01 forbids, so it is deferred (operator decision f).
7. **`reimport-scan` with `auto_create_context=true` on every run (D-09).** There is no separate first-run
   `import-scan` path and no manual per-repository setup. Every call carries an explicit, unique
   `test_title` so the two Trivy reports stay distinct, and `close_old_findings=true` so fixed findings are
   closed in place rather than piling up. `deduplication_on_engagement` is not sent (27-RESEARCH OQ4; see
   Consequences).
8. **Delete the PR's engagement on close, behind an exact-name guard (D-10).** A `defectdojo-cleanup` job
   runs only when `github.event_name == 'pull_request' && github.event.action == 'closed' &&
   vars.DEFECTDOJO_URL != ''`. Merged and abandoned PRs take the same path. The `dd-delete` step:
   - refuses an empty head ref, a head ref equal to the default branch, or an unknown default branch, and
     sends no request;
   - resolves the product with `products/?name_exact=` plus a client-side exact `==` comparison, and fails
     ("refusing to guess") if two products match exactly or a lookup is paginated;
   - lists engagements with `?product=<id>&name=ci/<head>` and keeps only exact `name ==` matches inside that
     product id, never a pattern or wildcard;
   - deletes every exact match (27-RESEARCH OQ1), requires HTTP 204 for each, and re-reads to confirm none
     remain;
   - exits 0 with `nothing-to-delete` when no product or engagement matches.

   `dd-cleanup-verify` fails red on any other outcome.
9. **A declared optional `workflow_call` secret, not `secrets: inherit` (D-11, D-12).** `security.yml`
   declares `DEFECTDOJO_API_TOKEN` with `required: false`. Both callers pass exactly that one secret. The
   caller-side names are the secret `DEFECTDOJO_API_TOKEN` and the repository variables `DEFECTDOJO_URL` (the
   on/off switch), `DEFECTDOJO_PRODUCT`, `DEFECTDOJO_PRODUCT_TYPE`, `DEFECTDOJO_CA_CERT` and
   `DEFECTDOJO_INSECURE`. The token must belong to a dedicated `is_staff=true`, `is_superuser=false` user
   (operator decision e).
10. **`closed` added to the PR caller, the scan jobs skip on it, and a separate scheduled caller (D-14,
    D-15).** `pr-security.yml` lists `types: [opened, synchronize, reopened, closed]`, restating the three
    defaults because a `types:` list replaces them (27-RESEARCH Pitfall 2). Each of the five scan jobs
    carries `if: github.event.action != 'closed'`, so a close does not rescan. The new optional
    `scheduled-security.yml` (job id `security`, operator decision d) runs at cron `0 6 * * *` with
    `timezone: "America/Toronto"` (the IANA key, so there is no DST drift), plus `workflow_dispatch`.
11. **Released additively as `v1.1.0` with `v1` moved (D-16, ADR-018).** Import is opt-in, no required
    context changes, and callers that change nothing keep working, so this is not a `v2`. 27-08 created the
    annotated tag `v1.1.0` (tag object `414fd3beb5a6d79d52316150a192803a4b0ece78`) and moved the
    lightweight `v1` from `cdf2c21` to `0f7e4e141d2a300d4be9a54efc137eb4510bb7ea`, the PR #21 merge commit,
    with `--force-with-lease` pinned to the pre-checked remote value. `v1.0.0` still dereferences to
    `cdf2c21`. Release `v1.1.0` is Latest. 27-10 re-read both refs from the GitHub API before closing
    DDOJO-02: `v1` → `0f7e4e1…`, `v1.1.0` → tag `414fd3b…` → `0f7e4e1…`, `releases/latest` → `v1.1.0`.
12. **Reachability is the consumer's problem, deferred to Phase 29 (D-17).** The job calls whatever
    `DEFECTDOJO_URL` names; the adoption guide says it must be reachable from the runner. No self-hosted
    runner, `runs-on` override, tunnel or exposure design was added.
13. **TLS verified by default; a CA-bundle variable; insecure only with a warning (D-18).** With no TLS
    variable set, curl verifies against the runner's trust store. `DEFECTDOJO_CA_CERT` (PEM text) is written
    to a temporary file and passed as `--cacert` (operator decision b). `DEFECTDOJO_INSECURE=true` enables
    `-k` and prints a `::warning::` on every run; if both are set, insecure wins and both warnings print.
    The proof never uses insecure mode.
14. **The proof runs the committed step bodies against a real DefectDojo on kind (D-19, D-20, D-21).**
    `scripts/defectdojo-import-proof.sh` extracts every DefectDojo `run:` body from `security.yml` with yq,
    refuses any body that contains `${{`, checks each step's env key set for equality with the contract,
    and executes those exact bodies. It runs as the Phase 26 kind smoke's post-hook, against the ADR-023
    chart with cert-manager and ingress-nginx. Imports run as a minted staff, non-superuser `ci-importer`,
    with TLS verified against the kind CA, and host resolution through a `CURL_HOME` `.curlrc` `resolve`
    entry rather than `/etc/hosts`. `defectdojo-import-proof.yml` runs it on GitHub on `workflow_dispatch` and
    on pull requests that touch the workflow, caller or proof files.
15. **The offline gates were extended with the jobs.** `check-workflow-uploads.sh` went from 10 to 16
    checks (27-01: scan vs side-channel job ids, SHA-PIN over every workflow file,
    SIDE-CHANNEL-NOT-REQUIRED, SIDE-CHANNEL-SHAPE, OPTIONAL-SECRET, NO-INTERPOLATION, IMPORT-VERIFY-PAIRING,
    INSECURE-WARNING) and then to 18 with no vacuous pass (27-04: SCAN-JOB-CLOSED-SKIP, CALLER-WIRING). This
    repository's `check-adoption-guide.sh` derives the five contexts from the scan-job ids only (27-01) and
    gained DEFECTDOJO-SECTION, going from 15 to 16 checks (27-09). The kind smoke gained one live check,
    `POST-HOOK` (12 to 13, 27-05/27-06).
16. **ADR-018's "one substitution point" is narrowed, here.** ADR-018 describes `gate_mode` as the only
    per-repo substitution point. That remains true of gating: `gate_mode` is still the only per-repo setting
    that changes whether a check passes or blocks. The `DEFECTDOJO_*` variables and the secret are opt-in
    side channels that change no check. This narrowing is recorded in this ADR and in the public workflow
    headers and adoption guide (27-02, 27-04, 27-09); ADR-018 itself is not edited.

### Measured evidence

- **Local proof (27-06):** `PROOF PASS - 85 assertions`, smoke `ALL PASS - 13 live check(s)` including
  `POST-HOOK: PASS`, harness exit 0, 225 s wall-clock, reports taken from PR Security run 36088129070.
  Run 1 raw versus imported per file: semgrep 7/7, checkov 14/14, trivy-fs 6/6, trivy-image 59/59,
  gitleaks 18/18, npm-audit-1 8/2, pip-audit-1 46/46, tflint.sarif 3/3. Exact equality was asserted for
  checkov, trivy-fs, trivy-image and pip-audit; the other four are bounded (`1 <= imported <= raw`)
  because their parsers merge entries (27-RESEARCH Pitfall 6). Run 2: for all 8 files
  `delta.created.total.total` was 0, `after.total.total` and `test_id` matched run 1, and the engagement
  still had 8 Tests. The token user read back as `is_staff=true is_superuser=false` and deleted an
  engagement.
- **PR proof on GitHub (27-07):** DefectDojo Import Proof run 36156728300 on PR head `7c47270`,
  `prove-import` success, `PROOF PASS - 85 assertions`, "Live proof" step 15:49:56Z to 15:55:14Z; its
  P-COUNTS lines show the same eight per-file numbers as the local run
  (`evidence/27-07-proof-run.log`). The PR Security run 36156728417 passed; both DefectDojo jobs showed
  `skipping` because `security-platform` sets no `DEFECTDOJO_URL`, and the five required contexts passed.
- **Merge (27-07):** PR #21 merged at 2026-09-25T16:08:32Z as the two-parent merge commit
  `0f7e4e141d2a300d4be9a54efc137eb4510bb7ea` (parents `71a112e`, `7c47270`); `git diff --stat 7c47270
  origin/main` was empty.
- **Close event (27-08):** run 36158851741, four seconds after the merge: all five scan jobs and both
  DefectDojo jobs skipped. No rescan.
- **Proof on `main` by dispatch (27-08):** run 36159160216 failed at `KIND-CELERY-PING` (`celery -A dojo
  inspect ping` exit 69, no nodes replied) before any import assertion ran. The operator chose "Re-dispatch
  once"; run 36160366711 passed with `PROOF PASS - 85 assertions`. The same tree passed that ping in
  36156728300 and 36160366711, so 36159160216 is classified as a harness flake (a single-shot ping with a
  5 s timeout), not an import regression.
- **Release blast radius (27-08):** moving `v1` published 62 commits (54 non-merge, 8 merges) across PRs
  #14 to #21, measured with `git rev-list --count`. An orchestrator brief had said 70; the source of 70 was
  not found, and 62 is the measured value.

## Consequences

**Improved:** findings from every PR and every scheduled default-branch run land in one place per branch,
updated in place, without the five required checks or their names changing.

**Improved:** the import is safe to ignore. A repository that sets nothing, a fork, or a Dependabot run
skips cleanly; a DefectDojo outage turns only a non-required job red.

**Tradeoff — the staff token is an instance-wide bypass.** At 3.3.200 open source, `is_staff` grants view,
edit, add, import and delete across every product on the instance, not only the caller's. A leaked
`DEFECTDOJO_API_TOKEN` is full-instance write. The adoption guide recommends a dedicated user, or a
dedicated instance. A non-staff user with per-product `authorized_users` membership can import, but at
3.3.200 open source cannot delete an engagement, and can create a new Product Type only with the Django
permission `dojo.add_product_type` (27-RESEARCH); that narrower set was not built or tested.

**Tradeoff — Mode B consumers must edit their own caller (operator decision g).** Moving `v1` gives them
the new `security.yml`, but the `closed` type and the `secrets:` pass live in the consumer's
`pr-security.yml`. Without those edits the import skips (empty token) and cleanup never fires. That is safe,
since old callers keep working, but it is not automatic.

**Tradeoff — two extra skipped check runs on every PR.** Every PR in a repository on `v1.1.0` now shows
`security / DefectDojo Import` and `security / DefectDojo Cleanup` check runs, skipped when not enabled
(`evidence/27-07-pr-checks.txt`). They are not required and block nothing, but a reader counting
`security / ...` rows now sees seven, not five.

**Hand-forward — Phase 28 owns deduplication.** `enable_deduplication` stays at its default (off) and
cross-test or cross-engagement deduplication tuning is Phase 28's. `deduplication_on_engagement` is read
only when an engagement is created (`get_or_create_engagement`); sending it on a later reimport has no
effect, so changing it for existing `ci/*` engagements will need `PATCH /api/v2/engagements/{id}/` or a
delete and re-create (27-RESEARCH OQ4).

**Side effect — Phase 29 (27-RESEARCH OQ5).** Once `security-platform` itself sets `DEFECTDOJO_URL` and
the secret, the proof workflow's `scans` job, which calls `security.yml`, will also import into the real
instance under `ci/<branch>`. Harmless, but it will surprise whoever reads that instance first.

**Follow-ups recorded, not done:**

- A stray public `v2.0` tag exists on `security-platform` (tag object `8d47cf9` → `c6395e1`, no release).
  The operator's decision in 27-08 was "Leave for now, note it". It is semver-higher than `v1.1.0` and a
  consumer might pin it by mistake.
- The Phase 26 smoke's `KIND-CELERY-PING` should retry within a bounded budget instead of one 5 s attempt
  (see run 36159160216).
- The adoption guide's section 8 says the caller job "emits no check run of its own, so there are five
  contexts here". That remains true of the required contexts, but since `v1.1.0` a PR shows seven
  `security / ...` check runs, two of them skipped side channels. Section 6 was updated in 27-09; section 8's
  wording is a follow-up.
- The planning repository that holds this ADR has the public `security-platform` repository as its
  `origin`. It must never be pushed.

## What was NOT verified

What WAS measured and must not be re-litigated: the 85-assertion proof, locally (27-06) and on GitHub
(36156728300, 36160366711); the per-file counts and the zero-created run 2 above; the staff,
non-superuser token importing, auto-creating and deleting; the cleanup's scope, refusal and no-match cases
against a live DefectDojo (27-06 P-SCOPE, P-CLEANUP, P-REFUSE, P-NOMATCH); a hostile branch name
`@dd-proof/$(touch pwned)` producing a literal engagement name and no `pwned` file (P-HOSTILE); the
insecure warning with no request made (P-INSECURE); the opt-out path on GitHub (27-07); the close event
skipping every job (27-08); and the remote tag readbacks.

1. **The five scan jobs' verify steps skip on `schedule` (27-RESEARCH Pitfall 4, operator decision f).**
   The 11 existing SARIF and artifact verify steps carry the pull-request `head.repo` guard, which is null
   on `schedule`. They skip rather than fail, so a scheduled run cannot detect a failed SARIF or artifact
   upload. Nothing turns falsely red; it is a blind spot. The import job's own verify does run on schedule.
   Fixing it touches all five scan jobs and was not done.
2. **The closed-PR reopen window (27-RESEARCH Pitfall 8, T-27-11).** 27-08 observed what Pitfall 8
   assumed: on the merged PR's head `7c47270`, every `security / ...` context has two check runs, `success`
   from 36156728417 and a newer `skipped` from the close run 36158851741. Skipped counts as passing. PR #21
   was merged, so nothing was blocked. Whether a close, reopen and merge could land before the reopen run's
   jobs queue, and so merge on the skipped runs, was not exercised.
3. **Job-level `concurrency` across separate caller runs (27-RESEARCH A3).** Both side-channel jobs share
   the group `defectdojo-<repository>-<head_ref or ref_name>` with `cancel-in-progress: false`, to stop a
   slow final import from re-creating an engagement after cleanup. That this serializes across separate
   runs of a called workflow is documented for ordinary workflows and assumed here; the race was not
   produced.
4. **dojo-pro permissions (27-RESEARCH A5).** The `is_staff` minimum was established from open-source
   3.3.200 source and proven live on it. A dojo-pro deployment may need a different permission set.
5. **`npm-audit-N` title drift (27-RESEARCH OQ3, operator decision f).** Numbered npm Tests follow
   `git ls-files` order. Adding a lockfile shifts which file `npm-audit-2` holds, so history is attributed
   to the wrong lockfile. `close_old_findings` keeps each Test self-consistent. The fix (shipping the
   lockfile list in the artifact) is a scan-job change and was deferred.
6. **Any consumer-repository import.** No consumer, and not `security-platform` itself, has set
   `DEFECTDOJO_URL`. Every live import in this phase went to an ephemeral DefectDojo on kind. The
   adoption guide's `gh secret set` / `gh variable set` commands were never run against a pilot.
7. **The scheduled run's wall-clock trigger.** `scheduled-security.yml` has not been observed firing at
   06:00 America/Toronto, and no scheduled run's duration was measured. The `timezone:` key was accepted by
   actionlint 1.7.12; the first real run is manual-only verification.
8. **Reachability from GitHub-hosted runners to a real instance (D-17).** Deferred to Phase 29.
9. **Mode A and Mode B consumer callers after the upgrade.** The updated Mode B caller shown in the
   adoption guide was not run in a consumer repository.
