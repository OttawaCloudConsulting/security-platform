# Phase 27: DefectDojo CI Auto-Import - Context

**Gathered:** 2026-09-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the canonical `security-platform` pipeline (`.github/workflows/security.yml` and its callers) so that, when a consumer repo opts in, each run's scan findings are imported into a DefectDojo instance through the DefectDojo API v2 (DDOJO-02). The phase also deletes a PR's branch engagement when the PR closes, adds a daily scheduled scan+import of the default branch, and proves the whole flow in a real GitHub Actions run against an ephemeral DefectDojo that the Phase 26 chart deploys on kind.

The import stays generic: the DefectDojo URL, product naming and token are consumer-supplied. Nothing environment-specific goes into the public repo.

NOT in this phase:
- Deduplication rule configuration and the triage workflow (Phase 28, DDOJO-03/04). Phase 27 uses reimport so repeated runs update in place. It does not tune DefectDojo dedup settings.
- Deploying DefectDojo to the homelab, and choosing how runners reach it: self-hosted runner, tunnel or public ingress (Phase 29, DDOJO-05).
- Fixes to the five open Phase 26 code-review warnings (`26-REVIEW.md`), unless the harness in D-20 cannot run without one of them.

</domain>

<decisions>
## Implementation Decisions

### Import job shape
- **D-01:** Add **one new job** to `security.yml`, `defectdojo-import`. It has `needs:` on all five scan jobs (`sast`, `iac`, `sca`, `container`, `secrets`) and `if: always()` plus the enablement guard (D-02). It downloads the five existing artifacts (`semgrep-results`, `checkov-results`, `sca-results`, the container artifact, `gitleaks-results`) and imports each report file. The five scan jobs are not changed, except where D-12 or D-15 needs a skip guard.
- **D-02:** Import is **opt-in**. The job runs only when the caller repo sets the `DEFECTDOJO_URL` repository variable **and** the token secret is present. When either is unset, the job is skipped and the repo behaves exactly as it does today. Existing callers that change nothing keep working.
- **D-03:** Failure behaviour follows the existing upload+verify pattern. The import step is `continue-on-error: true` (ADR-001 carve-out for side-channel uploads). A following **verify step fails red** when an import did not land. The import job is **never a required check**: `scripts/set-required-checks.sh` and the five frozen required contexts stay unchanged, so DefectDojo availability can never block a merge. The same applies to the cleanup job (D-10).
- **D-04:** The upload client is **plain `curl` to DefectDojo API v2**, with one call per report file. Do not add a marketplace action. Response parsing and assertions use inline `python3`, like the existing verify steps.

### Product / engagement mapping
- **D-05:** The **Product name** comes from the optional caller variable `DEFECTDOJO_PRODUCT`. When it is unset, the product name is `github.repository`.
- **D-06:** The **Product Type** name has a fixed default and can be overridden by the optional variable `DEFECTDOJO_PRODUCT_TYPE`. The exact default string is Claude's discretion (for example `CI`).
- **D-07:** Each branch gets its **own engagement**, named `ci/<branch>`. A PR run uses the PR head branch. A scheduled run uses the default branch. Each tool report maps to **one Test** in that engagement. Every run uses **`reimport-scan`**, so the same Test is updated in place: new findings are added and fixed findings are closed. Findings do not pile up per run.
- **D-08:** Each tool uses its **native DefectDojo parser**, for example Semgrep JSON, Checkov, Trivy (both the filesystem and image reports), Gitleaks, NPM Audit v7+ and pip-audit. **SARIF is used only where no native file exists** (tflint, which emits SARIF only). This honours the CICD-03 retention contract comment in `security.yml` ("normalising would destroy import fidelity"). The researcher confirms the exact `scan_type` strings against the pinned DefectDojo 3.3.200 parser list.
- **D-09:** Use **`auto_create_context=true`** on import and reimport. The first run creates the Product Type, Product and Engagement. No manual DefectDojo setup is needed per repo.
- **D-10:** When a PR is **closed** (merged or abandoned, same behaviour for both), a small cleanup job **DELETEs** that PR's `ci/<head-branch>` engagement and its findings through the API. The operator chose delete over "mark Completed".
  - **Safety constraint (Claude-derived, required):** the delete may target only the engagement named `ci/<head_ref>` inside the resolved product. It must never delete the default branch's engagement, and it must never delete by a pattern or wildcard. The job resolves the engagement id by exact name and product, and it does nothing when there is no match.
  - The API token therefore needs delete rights on engagements as well as import/create rights. The researcher documents the minimum DefectDojo permission set the token needs.

### Credentials and triggers
- **D-11:** Caller-side names:
  - Secret `DEFECTDOJO_API_TOKEN`.
  - Variable `DEFECTDOJO_URL`. This variable is the on/off switch.
  - Optional variables `DEFECTDOJO_PRODUCT` and `DEFECTDOJO_PRODUCT_TYPE`.
  - Optional variable `DEFECTDOJO_INSECURE` (D-18).
- **D-12:** The token reaches the called workflow as a **declared optional `workflow_call` secret** (`secrets: DEFECTDOJO_API_TOKEN: required: false`). The caller passes it explicitly. Do **not** use `secrets: inherit` (least privilege). This matters because Mode B callers invoke a remote workflow.
- **D-13:** On **fork and Dependabot** runs, where no secret is available, the import and cleanup jobs are **skipped cleanly** and log the reason. Use the same guard family as the existing verify steps.
- **D-14:** Add a **daily scheduled** scan and import of the default branch at **06:00 local time**. Local time is assumed to be America/Toronto; the operator is in Ottawa. The researcher checks whether GitHub Actions `schedule` now supports a timezone key. If it does not, pick a UTC cron and document the DST drift of one hour.
- **D-15:** The schedule lives in a **new caller file**, separate from `pr-security.yml` (name is Claude's discretion, for example `scheduled-security.yml`). Consumers who want the schedule adopt it as a second file.
  - `pr-security.yml` changes in two ways: it adds `closed` to its `pull_request` types for D-10, and it passes the optional secret (D-12).
  - Keep the frozen `security` job id and the `name: security` value in `pr-security.yml`, so the five required-context names do not change.
  - When the `closed` event fires, the five scan jobs **must not rescan**. Only the cleanup job runs.
- **D-16:** Release as an **additive change on v1**. Publish a new v1.x tag and move `v1`, following ADR-018. This is allowed because import is opt-in, no required-check name changes, and old callers keep working unchanged against the new `security.yml`.

### Proof, reachability and TLS
- **D-17:** **Reachability is deferred to Phase 29.** The job calls whatever `DEFECTDOJO_URL` names, and the docs state that the URL must be reachable from the runner. This phase does not add a self-hosted runner, `runs-on` override, tunnel or public-exposure design.
- **D-18:** TLS is **verified by default**. The optional variable `DEFECTDOJO_INSECURE=true` enables `curl -k`. When it is set, the job emits a `::warning::` annotation on **every run**, stating that TLS verification is off. The proof harness (D-20) must **not** use insecure mode. It verifies against the kind self-signed CA through a CA bundle, so the verified path is the one that gets tested. Whether to also offer an optional CA-bundle input is Claude's discretion.
- **D-19:** DDOJO-02 is proven by a **real GitHub Actions run** in `security-platform` against an **ephemeral DefectDojo** that runs inside the runner.
- **D-20:** The harness is **kind + the Phase 26 chart**, following the `scripts/defectdojo-live-smoke.sh` pattern: ingress-nginx, a cert-manager self-signed issuer, pre-created Secrets and a created API token. Then the real `defectdojo-import` job logic runs against it, and API assertions check:
  - the product, the `ci/<branch>` engagement and one Test per tool exist;
  - the imported finding counts match the artifact contents;
  - a second run reimports with no duplicate findings;
  - the PR-close delete removes only the target engagement.
- **D-21:** The test workflow triggers are `workflow_dispatch`, plus **path-filtered PRs**: PRs that touch `security.yml`, the caller files, or the import/cleanup code or scripts. It does not run on every PR.

### Records
- **D-22:** Write **ADR-024**, covering the import job shape, naming, reimport-per-branch, delete-on-close, opt-in variables, TLS stance and v1 additive versioning, and add its row to the ADR index.
  - Add an **"Enable DefectDojo import"** section to `docs/adoption-guide.md`. It covers the variables, the secret, the second caller file, the token permissions and the reachability note.
  - `bash scripts/check-adoption-guide.sh` must stay green.
  - `security-platform` `scripts/check-workflow-uploads.sh` must stay green, or be extended deliberately.

### Claude's Discretion
- The Product Type default string, the scheduled caller's file name, the test workflow and script names, and whether to add a CA-bundle variable.
- Whether the cleanup job lives in `security.yml` (gated on `github.event.action == 'closed'`) or elsewhere, provided D-15's constraints hold.
- The exact per-file import loop structure and the Test titles.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirement and project constraints
- `.planning/REQUIREMENTS.md`: DDOJO-02 text; the Out of Scope table.
- `.planning/PROJECT.md`: the v3.0 goal and the generic-first Key Decision (environment values never go into the public repo).
- `.planning/ROADMAP.md`: the Phase 27 goal, plus the Phase 28 (dedup/triage) and Phase 29 (homelab live) boundaries.

### Workflow under change (local clone of security-platform)
- `repos/security-platform/.github/workflows/security.yml`: the five scan jobs, their artifact names, and the RETENTION FORMAT comment (native outputs kept for DefectDojo parsers). It also holds the upload+verify pairs and the fork/Dependabot guard `github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'`. Note: that guard evaluates false on `schedule` events, because `github.event.pull_request` is null. The researcher must decide how existing verify steps behave on scheduled runs.
- `repos/security-platform/.github/workflows/pr-security.yml`: the caller. It holds the frozen `security` job id, the single `GATE_MODE` substitution point, the Mode A/B adoption comments, and the note forbidding a bare `vars` passthrough in `with:`.
- `repos/security-platform/scripts/set-required-checks.sh`: the five required contexts. They must not gain the import or cleanup job.
- `repos/security-platform/scripts/check-workflow-uploads.sh`: the existing workflow upload gate.
- `repos/security-platform/scripts/defectdojo-live-smoke.sh`: the kind + chart harness to extend for D-20.
- `repos/security-platform/kubernetes/defectdojo/`: the Phase 26 chart (values, README Secret contract).

### ADRs
- `docs/adr/adr001-remove-continue-on-error.md`: the continue-on-error stance for uploads (D-03).
- `docs/adr/adr004-pin-actions-to-sha-digest.md`: any action used in new jobs (download-artifact, kind setup) is SHA-pinned.
- `docs/adr/adr017-configurable-gate-mode-and-required-checks.md`: the gate mode and the required-check set.
- `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md`: v1 tag rules (D-16).
- `docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md`: DefectDojo 1.9.53 / app 3.3.200 pin, TLS guard.
- `docs/adr/README.md`: the ADR index (the ADR-024 row goes here).

### Prior phase context
- `.planning/phases/26-defectdojo-generic-chart/26-CONTEXT.md`: chart decisions (existingSecret, ingress/TLS, kind smoke shape).
- `.planning/phases/26-defectdojo-generic-chart/26-REVIEW.md`: five open warnings; be aware of them when reusing the smoke harness.

### Docs
- `docs/adoption-guide.md` and `scripts/check-adoption-guide.sh`: adoption procedure and its gate (D-22).

### Upstream
- DefectDojo API v2 `import-scan` / `reimport-scan` endpoints (`auto_create_context`, `product_name`, `product_type_name`, `engagement_name`, `test_title`, `scan_type`, `close_old_findings`) and the engagement DELETE endpoint. Check them against the pinned app version 3.3.200, not against latest docs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The five `actions/upload-artifact` steps (SHA-pinned v7.0.1) with unique artifact names. The import job downloads these artifacts.
- The inline `python3` verify-step idiom (parse the report, print counts, `exit 1` on mismatch). Reuse it for import-result assertions.
- `scripts/defectdojo-live-smoke.sh`, which already brings up DefectDojo over TLS on kind with an admin login. Extend it to mint an API token and drive the imports.

### Established Patterns
- Upload with `continue-on-error`, followed by a verify step that fails red. Fork and Dependabot runs are guarded.
- A single per-repo substitution point through repository `vars`, resolved in the callee. The new `DEFECTDOJO_*` variables follow the same `vars` mechanism.
- All third-party actions are pinned to a full SHA.
- Every file consumers copy carries heavy WHY-comments.

### Integration Points
- `security.yml` gains a job, an optional secret declaration and possibly `closed`/`schedule` guards on the scan jobs.
- `pr-security.yml` gains the `closed` type and the secret pass. A new scheduled caller file is added.
- DefectDojo endpoint: the ingress host and TLS from the Phase 26 chart.

</code_context>

<specifics>
## Specific Ideas

- The operator explicitly chose **delete** (not close) for PR engagements on PR close. The delete is irreversible, so the exact-name, no-default-branch guard in D-10 is mandatory, not optional.
- 06:00 local, with the operator in Ottawa (America/Toronto). See D-14 for the DST handling.
- Import results must be assertable: the proof checks per-tool finding counts against the artifact contents, not only HTTP 201.

</specifics>

<deferred>
## Deferred Ideas

- The reachability model for the homelab DefectDojo (self-hosted runner, tunnel or public ingress): Phase 29.
- DefectDojo dedup algorithm/settings tuning and the triage workflow: Phase 28.
- Push-to-default-branch trigger: not chosen. The daily schedule covers the default branch instead. Revisit if the dashboard state after a merge lags too far behind.
- The five open Phase 26 review warnings (`26-REVIEW.md`): separate follow-up.

</deferred>

---

*Phase: 27-defectdojo-ci-auto-import*
*Context gathered: 2026-09-25*
