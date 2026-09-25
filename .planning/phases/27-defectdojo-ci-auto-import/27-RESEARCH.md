# Phase 27: DefectDojo CI Auto-Import - Research

**Researched:** 2026-09-25
**Domain:** GitHub Actions reusable workflows (callee/caller semantics, schedule, secrets/vars) + DefectDojo API v2 at app 3.3.200 (import/reimport, auto-create, authorization, delete) + kind-based live proof
**Confidence:** HIGH for DefectDojo behaviour (read from the pinned `3.3.200` source tag) and GitHub Actions syntax (official docs + local actionlint); MEDIUM for the harness runtime shape and finding-count assertions (not yet measured live)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Import job shape
- **D-01:** Add **one new job** to `security.yml`, `defectdojo-import`. It has `needs:` on all five scan jobs (`sast`, `iac`, `sca`, `container`, `secrets`) and `if: always()` plus the enablement guard (D-02). It downloads the five existing artifacts (`semgrep-results`, `checkov-results`, `sca-results`, the container artifact, `gitleaks-results`) and imports each report file. The five scan jobs are not changed, except where D-12 or D-15 needs a skip guard.
- **D-02:** Import is **opt-in**. The job runs only when the caller repo sets the `DEFECTDOJO_URL` repository variable **and** the token secret is present. When either is unset, the job is skipped and the repo behaves exactly as it does today. Existing callers that change nothing keep working.
- **D-03:** Failure behaviour follows the existing upload+verify pattern. The import step is `continue-on-error: true` (ADR-001 carve-out for side-channel uploads). A following **verify step fails red** when an import did not land. The import job is **never a required check**: `scripts/set-required-checks.sh` and the five frozen required contexts stay unchanged, so DefectDojo availability can never block a merge. The same applies to the cleanup job (D-10).
- **D-04:** The upload client is **plain `curl` to DefectDojo API v2**, with one call per report file. Do not add a marketplace action. Response parsing and assertions use inline `python3`, like the existing verify steps.

#### Product / engagement mapping
- **D-05:** The **Product name** comes from the optional caller variable `DEFECTDOJO_PRODUCT`. When it is unset, the product name is `github.repository`.
- **D-06:** The **Product Type** name has a fixed default and can be overridden by the optional variable `DEFECTDOJO_PRODUCT_TYPE`. The exact default string is Claude's discretion (for example `CI`).
- **D-07:** Each branch gets its **own engagement**, named `ci/<branch>`. A PR run uses the PR head branch. A scheduled run uses the default branch. Each tool report maps to **one Test** in that engagement. Every run uses **`reimport-scan`**, so the same Test is updated in place: new findings are added and fixed findings are closed. Findings do not pile up per run.
- **D-08:** Each tool uses its **native DefectDojo parser**, for example Semgrep JSON, Checkov, Trivy (both the filesystem and image reports), Gitleaks, NPM Audit v7+ and pip-audit. **SARIF is used only where no native file exists** (tflint, which emits SARIF only). This honours the CICD-03 retention contract comment in `security.yml` ("normalising would destroy import fidelity"). The researcher confirms the exact `scan_type` strings against the pinned DefectDojo 3.3.200 parser list.
- **D-09:** Use **`auto_create_context=true`** on import and reimport. The first run creates the Product Type, Product and Engagement. No manual DefectDojo setup is needed per repo.
- **D-10:** When a PR is **closed** (merged or abandoned, same behaviour for both), a small cleanup job **DELETEs** that PR's `ci/<head-branch>` engagement and its findings through the API. The operator chose delete over "mark Completed".
  - **Safety constraint (Claude-derived, required):** the delete may target only the engagement named `ci/<head_ref>` inside the resolved product. It must never delete the default branch's engagement, and it must never delete by a pattern or wildcard. The job resolves the engagement id by exact name and product, and it does nothing when there is no match.
  - The API token therefore needs delete rights on engagements as well as import/create rights. The researcher documents the minimum DefectDojo permission set the token needs.

#### Credentials and triggers
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

#### Proof, reachability and TLS
- **D-17:** **Reachability is deferred to Phase 29.** The job calls whatever `DEFECTDOJO_URL` names, and the docs state that the URL must be reachable from the runner. This phase does not add a self-hosted runner, `runs-on` override, tunnel or public-exposure design.
- **D-18:** TLS is **verified by default**. The optional variable `DEFECTDOJO_INSECURE=true` enables `curl -k`. When it is set, the job emits a `::warning::` annotation on **every run**, stating that TLS verification is off. The proof harness (D-20) must **not** use insecure mode. It verifies against the kind self-signed CA through a CA bundle, so the verified path is the one that gets tested. Whether to also offer an optional CA-bundle input is Claude's discretion.
- **D-19:** DDOJO-02 is proven by a **real GitHub Actions run** in `security-platform` against an **ephemeral DefectDojo** that runs inside the runner.
- **D-20:** The harness is **kind + the Phase 26 chart**, following the `scripts/defectdojo-live-smoke.sh` pattern: ingress-nginx, a cert-manager self-signed issuer, pre-created Secrets and a created API token. Then the real `defectdojo-import` job logic runs against it, and API assertions check:
  - the product, the `ci/<branch>` engagement and one Test per tool exist;
  - the imported finding counts match the artifact contents;
  - a second run reimports with no duplicate findings;
  - the PR-close delete removes only the target engagement.
- **D-21:** The test workflow triggers are `workflow_dispatch`, plus **path-filtered PRs**: PRs that touch `security.yml`, the caller files, or the import/cleanup code or scripts. It does not run on every PR.

#### Records
- **D-22:** Write **ADR-024**, covering the import job shape, naming, reimport-per-branch, delete-on-close, opt-in variables, TLS stance and v1 additive versioning, and add its row to the ADR index.
  - Add an **"Enable DefectDojo import"** section to `docs/adoption-guide.md`. It covers the variables, the secret, the second caller file, the token permissions and the reachability note.
  - `bash scripts/check-adoption-guide.sh` must stay green.
  - `security-platform` `scripts/check-workflow-uploads.sh` must stay green, or be extended deliberately.

### Claude's Discretion
- The Product Type default string, the scheduled caller's file name, the test workflow and script names, and whether to add a CA-bundle variable.
- Whether the cleanup job lives in `security.yml` (gated on `github.event.action == 'closed'`) or elsewhere, provided D-15's constraints hold.
- The exact per-file import loop structure and the Test titles.

### Deferred Ideas (OUT OF SCOPE)
- The reachability model for the homelab DefectDojo (self-hosted runner, tunnel or public ingress): Phase 29.
- DefectDojo dedup algorithm/settings tuning and the triage workflow: Phase 28.
- Push-to-default-branch trigger: not chosen. The daily schedule covers the default branch instead. Revisit if the dashboard state after a merge lags too far behind.
- The five open Phase 26 review warnings (`26-REVIEW.md`): separate follow-up.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DDOJO-02 | `security-platform` CI scan jobs automatically import SARIF/JSON findings into DefectDojo after each run | Verified `scan_type` strings (table below); `reimport-scan` + `auto_create_context` semantics at 3.3.200 (one call per file covers first and later runs); minimum token identity (`is_staff`, not superuser); engagement DELETE is synchronous 204; `vars`/optional-secret resolution for both modes; `timezone:` on `schedule` is GA; harness shape (kind + chart + extract-and-run of the committed step body); gate extensions required for `check-workflow-uploads.sh` and `check-adoption-guide.sh` |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- This repository is documentation. The workflow, scripts and chart live in `OttawaCloudConsulting/security-platform` (local clone `repos/security-platform/`). Code changes go there in a PR; ADR/adoption-guide changes go here.
- **ADRs are append-only.** ADR-024 is a new file. Do not edit accepted ADRs (for example ADR-001, ADR-017, ADR-018, ADR-023). Only the ADR index `docs/adr/README.md` gains a row.
- Preserve the ASCII diagrams and the 4-phase layered structure in the primary document if it is touched.
- **Never set the executable bit on scripts.** Always invoke them as `bash scripts/x.sh`, including inside GitHub Actions `run:` blocks. Never run `chmod +x`.
- Anti-slop rules: on a failure, stop and report without silent retries. Verify every 3 to 5 actions. Never use silent fallbacks (`|| true` on an assertion, `try/except: pass`). Get confirmation before irreversible actions. The PR-close DELETE is irreversible, so its guard is mandatory. Pushing the `v1.x` tag and moving `v1` is also irreversible-ish and needs the operator's explicit confirmation step.
- Generic-first (PROJECT.md): no environment values such as the homelab URL, product names or tokens go into the public repo.
- Files that consumers copy carry heavy WHY-comments. Every third-party action is SHA-pinned (ADR-004).

## Summary

At the pinned version, DefectDojo `3.3.200` can do everything D-01 to D-10 need with **one call per report file, `POST /api/v2/reimport-scan/`, with `auto_create_context=true`**. When no matching Test exists, the reimport path creates the Product Type, Product, Engagement and Test and imports into them, with `close_old_findings` forced to false. On later runs it updates that Test in place, and `close_old_findings` defaults to true. `import-scan` is never needed. The Test lookup uses `engagement + test_title + scan_type` and otherwise falls back to "the last Test of this scan_type", so an explicit, unique `test_title` per report file is mandatory. Trivy fs and Trivy image both use `"Trivy Scan"`, and there can be several `npm-audit-N.json` files. All eight `scan_type` strings were read from the `3.3.200` parser source. There is a native `"TFLint Scan"` parser, but it reads only `tflint --format json`. The workflow emits only SARIF for tflint, so tflint imports as `"SARIF"`, which matches D-08.

The **authorization model changed in 3.x open-source**. The Reader/Writer/Maintainer/Owner/API_Importer roles are inert stubs, and OS authorization is now `is_superuser`, `is_staff` or `authorized_users` membership. Engagement **delete requires `is_staff`**, and creating a **new Product Type needs `is_staff`** (or the Django permission `dojo.add_product_type`). The minimum identity for the single token in D-11 is therefore a **dedicated user with `is_staff=true` and `is_superuser=false`**. Staff is a global bypass for view, edit, add, import and delete on all products, and the docs must say this plainly. Engagement DELETE is synchronous by default (`DD_ASYNC_OBJECT_DELETE=False`) and returns **204**. Findings cascade through Test to Engagement.

On the GitHub side, `schedule` **supports `timezone:`**. This has been GA since 2026-03-19, it is in the docs, and local actionlint 1.7.12 accepts it. D-14 is therefore `cron: '0 6 * * *'` plus `timezone: "America/Toronto"`, with no DST drift note needed. `secrets` is **not** available in `jobs.<id>.if`, but `vars` is, and inside a called workflow `vars` resolves to the **caller's** repository in both modes. Two in-repo facts shape the plan more than any upstream fact.

1. **Both offline gates hard-code "exactly five jobs".**
   - `check-workflow-uploads.sh` JOB-SHAPE fails on `len(jobs) != 5`, on any `needs:`, and on any drift in the name list.
   - `check-adoption-guide.sh` DERIVE-CONTEXTS fails on `!= 5` callee job names and `!= 1` caller job name. Its SIXTH-CONTEXT check fails on any extra `security / ...` string in the guide.

   Adding `defectdojo-import` turns both red, so both gates must be extended deliberately in the same PR.
2. **The logic must be inline in `security.yml`.** Mode A consumers copy three files and have no `scripts/`, and the harness's kind cluster is unreachable from a called workflow's separate runners. The harness should therefore **extract the committed `run:` body by job and step id and execute it**, using the same technique `check-detector-parity.sh` already uses. There is one source of truth and no duplicated script.

**Primary recommendation:** Build one inline `reimport-scan` loop step, driven only by environment variables, into a new `defectdojo-import` job in `security.yml`, plus a `defectdojo-cleanup` job gated on `github.event.action == 'closed'`. Use `timezone: America/Toronto` in a new `scheduled-security.yml`. Extend both gates to tell "scan jobs" from "side-channel jobs". Prove it with a `defectdojo-import-proof.yml` workflow that runs the real scans via `uses: ./.github/workflows/security.yml`, then brings up kind and the chart in a second job and executes the extracted step bodies against it with `--cacert`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Opt-in switch, product naming, TLS mode | Caller repo config (`vars`, secret) | Callee env resolution | D-02/D-11: per-repo values never live in the public YAML; `vars` resolves to caller in a called workflow [CITED: docs.github.com variables reference] |
| Artifact retrieval | CI runner (callee job) | GitHub artifact service | Same-run artifacts via `actions/download-artifact` v8.0.1 |
| Report parsing / finding identity | DefectDojo backend (parsers) | — | D-08 native parsers; never normalise in CI |
| Product/Engagement/Test creation | DefectDojo backend (`auto_create_context`) | — | D-09; server-side get-or-create with row locks [VERIFIED: django-DefectDojo@3.3.200 dojo/importers/auto_create_context.py] |
| Engagement lookup + delete guard | CI runner (cleanup job, inline python3) | DefectDojo API filters | Exact-name/product/default-branch guard must be client-side; server `name` filter is exact but names are not unique |
| TLS trust | CI runner (curl `--cacert` / system store) | Consumer-supplied CA | D-18 verified by default |
| Merge gating | GitHub branch ruleset (5 frozen contexts) | — | D-03: import/cleanup never required |
| Live proof | GitHub-hosted runner (kind + Helm chart) | — | D-19/D-20; cluster must live on the SAME runner as the import logic |

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| DefectDojo API v2 `reimport-scan` | app 3.3.200 (chart 1.9.53) | Create-or-update one Test per report file | Pinned by ADR-023; verified in source [VERIFIED: django-DefectDojo@3.3.200 dojo/api_v2/serializers.py:764-930] |
| `curl` (runner-preinstalled) | ubuntu-24.04 image | Multipart POST, GET, DELETE | D-04 |
| `python3` stdlib (`json`, `urllib.parse`, `subprocess` not needed) | 3.12.3 on ubuntu-24.04 | Response parsing, assertions, URL-encoding | D-04; existing verify-step idiom |
| `actions/download-artifact` | **v8.0.1**, SHA `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` | Download the five same-run artifacts | Latest release; tag is a lightweight commit ref [VERIFIED: gh api repos/actions/download-artifact] |

### Supporting (harness only)
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| kind | 0.33.0 (preinstalled on ubuntu-24.04 and 26.04 images) | Ephemeral cluster | Proof workflow [VERIFIED: actions/runner-images Ubuntu2404-Readme.md] |
| kubectl | 1.37.0 (preinstalled) | Cluster ops | Proof workflow |
| Helm | **v4.3.0** — must be INSTALLED; ubuntu-latest (=24.04) ships Helm 3.22.0 | Chart install | The Phase 26 smoke was measured only on Helm v4.3.0 ("Helm 3 wait semantics were not measured"). Install via download + `sha256sum -c` with `86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb  helm-v4.3.0-linux-amd64.tar.gz` [VERIFIED: get.helm.sh sha256sum file] |
| yq / jq / openssl | 4.53.6 / 1.7 / preinstalled | Smoke preflight hard tier | Already required by `defectdojo-live-smoke.sh` |
| cert-manager / ingress-nginx | v1.21.2 / controller-v1.15.1 | Smoke infra | Reuse the smoke's pins unchanged |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `reimport-scan` only | `import-scan` first, `reimport-scan` after | Needs a "does the Test exist?" pre-query; `reimport-scan` with `auto_create_context` already does get-or-create. No benefit. |
| SARIF for tflint | Add `tflint --format json` + `"TFLint Scan"` native parser | Native parser exists at 3.3.200 but would require changing the `sca` scan job (D-01 forbids) and the artifact. Defer; note in ADR-024. |
| Inline logic + extraction in harness | Separate `scripts/defectdojo-import.sh` + parity gate | Mode A consumers have no `scripts/`; a copy needs a parity gate. Extraction by job+step id gives one source of truth (precedent: `check-detector-parity.sh`). |
| Checkout own repo via `job.workflow_repository`/`job.workflow_sha` | — | New 2026-09-03 context; in Mode A it resolves to the CONSUMER repo (no scripts), so it only helps Mode B. Not used. |
| Marketplace DefectDojo import action | — | Forbidden by D-04 |
| `azure/setup-helm` (v5.0.1, SHA `9bc31f4ebc9c6b171d7bfbaa5d006ae7abdb4310`) | Download + sha256 | Project precedent is download-verify-extract (tflint, gitleaks); avoids a new third-party action. |

**Installation:** nothing from npm or PyPI. The harness downloads the Helm binary and checks it:
```bash
curl -sSfL -o helm.tar.gz https://get.helm.sh/helm-v4.3.0-linux-amd64.tar.gz
echo "86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb  helm.tar.gz" | sha256sum -c -
sudo tar xzf helm.tar.gz -C /usr/local/bin --strip-components=1 linux-amd64/helm
```

## Package Legitimacy Audit

This phase installs **no packages from npm, PyPI or crates**. The inline logic uses runner-preinstalled `curl` and the Python 3 standard library only. The external artifacts are:

| Artifact | Source | Verification | Disposition |
|----------|--------|--------------|-------------|
| `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` (v8.0.1) | github.com/actions (first-party) | SHA read via `gh api .../git/ref/tags/v8.0.1` (object type `commit`) | Approved; SHA-pin per ADR-004 |
| Helm v4.3.0 linux-amd64 tarball | get.helm.sh (official) | sha256 from the official `.sha256sum` file | Approved; harness only |

**Packages removed due to slopcheck [SLOP] verdict:** none. slopcheck was not run because there are no registry packages.
**Packages flagged as suspicious [SUS]:** none.

## Verified DefectDojo facts at 3.3.200

These were read from a shallow clone of `DefectDojo/django-DefectDojo` at tag `3.3.200` (tag object `90af8ff`, commit `395f0405`, dated 2026-09-21). They are **not** taken from the latest docs.

### scan_type strings (research item 1)

| Report file (artifact) | `scan_type` (exact) | Parser file | Notes |
|---|---|---|---|
| `semgrep-results.json` (`semgrep-results`) | `Semgrep JSON Report` | dojo/tools/semgrep/parser.py:65 | Parser merges results with the same title+file_path+line (`nb_occurences++`) |
| `checkov-results.json` (`checkov-results`) | `Checkov Scan` | dojo/tools/checkov/parser.py:57 | Counts `results.failed_checks` across the list-or-object report |
| `trivy-fs.json` (`sca-results`) | `Trivy Scan` | dojo/tools/trivy/parser.py:58 | Same scan_type as the image report, so the Test title must differ |
| `trivy-image.json` (`trivy-image-results`, conditional) | `Trivy Scan` | same | Present only when a Dockerfile was found |
| `gitleaks-results.json` (`gitleaks-results`) | `Gitleaks Scan` | dojo/tools/gitleaks/parser.py:59 | Parser merges by hash key |
| `npm-audit-N.json` (`sca-results`, 0..n) | `NPM Audit v7+ Scan` | dojo/tools/npm_audit_7_plus/parser.py:31 | Parser keys by title+severity. Requires `auditReportVersion` |
| `pip-audit-N.json` (`sca-results`, 0..n) | `pip-audit Scan` | dojo/tools/pip_audit/parser.py:15 | Handles the `dependencies` format the workflow emits |
| `tflint.sarif` (`sca-results`, conditional) | `SARIF` | dojo/tools/sarif/parser.py:95 | `TFLint Scan` exists (dojo/tools/tflint/parser.py:24) but reads **JSON only** ("generated with 'tflint --format json'"), so SARIF is correct for D-08. The SARIF parser is multi-run and `get_tests`-based. The Test type becomes `<driver> (SARIF)`, but the Test's `scan_type` stays `SARIF` and the title is kept, so reimport matching still works (dojo/importers/base_importer.py:284-340) |

The `.json` and `.sarif` extensions are both in the default `DD_FILE_IMPORT_TYPES` (dojo/settings/settings.dist.py:266). The file-size cap is 100 MB.

### reimport-scan parameters and matching (research item 2)

- **Fields** (CommonImportScanSerializer, serializers.py:390-515, ReImportScanSerializer :764-800): `scan_type` (required), `file`, `product_type_name`, `product_name`, `engagement_name`, `test_title`, `auto_create_context`, `deduplication_on_engagement`, `close_old_findings` (**reimport default `True`**, :781), `do_not_reactivate` (default False), `minimum_severity` (default `Info`), `active`/`verified` (omit to use the tool's own values), `scan_date` (rejected if in the future, so omit it), `version`, `branch_tag`, `commit_hash`, `build_id`, `source_code_management_uri` (engagement creation only), `engagement_end_date`, `tags`, `deduplication_execution_mode` (`async` default, `async_wait`, `sync`), and `environment` (default `Development`, auto-created only when `auto_create_context`).
- **Matching** (auto_create_context.py):
  - Product is looked up by exact `name`. If the product exists under a **different** Product Type, a `ValueError` becomes a **400** (:125-150).
  - Engagement is looked up by `product + name`, taking the **last** match. Engagement names are *not* unique (:164-188).
  - Test is looked up by `engagement + title + scan_type` when a `test_title` is supplied. **Otherwise it takes the last Test with that scan_type** (:190-212).
- **First run:** no Test exists and `auto_create_context=true`, so `get_or_create_engagement` runs, then the DefaultImporter with `close_old_findings=False` (serializers.py:866-878). A new engagement gets `engagement_type="CI/CD"`, status "In Progress" and `target_end` = today + 365 days (auto_create_context.py:331).
- **Response:** HTTP **201**, with `test_id`, `engagement_id`, `product_id`, `product_type_id` and `statistics`. The first run returns `statistics.after` only. Later runs return `before`, `delta` and `after`. `delta` has `created`, `closed`, `reactivated` and `untouched`, each `{severity: {active, verified, duplicate, false_p, out_of_scope, is_mitigated, risk_accepted, total}, total: {...}}`. `delta` needs `DD_TRACK_IMPORT_HISTORY`, which defaults to True (settings.dist.py:226). The vendored chart configmap does not override it.
- **Engagement DELETE** `DELETE /api/v2/engagements/{id}/`: when `ASYNC_OBJECT_DELETE` is on it runs `async_delete`, otherwise `instance.delete()`. It **returns 204** in both cases (dojo/engagement/api/views.py:86-93). `DD_ASYNC_OBJECT_DELETE` defaults to **False**, so the delete is synchronous (settings.dist.py:256), and the vendored chart does not override it. Test to Engagement and Finding to Test are both `on_delete=CASCADE` (dojo/test/models.py:51, dojo/finding/models.py:215), so the findings go with the engagement. The object is fetched through `get_authorized_engagements("view")`, so an engagement the token cannot see returns **404**.
- **In-place matching does not depend on the global dedup switch.** `System_Settings.enable_deduplication` defaults to **False** (dojo/system_settings/models.py). The reimporter never reads it: it computes `hash_code` for every parsed finding and matches candidates using `DEDUPLICATION_ALGORITHM_PER_PARSER` (dojo/importers/default_reimporter.py:218-270, 942-990). D-07 in-place update and close work on a fresh instance with no settings change. Hand-forward to Phase 28: cross-test and cross-engagement dedup is what `enable_deduplication` controls.
- **Transport:** `ReImportScanView.parser_classes = [MultiPartParser]` (dojo/api_v2/views.py:~492), so the body must be multipart (`curl -F` / `--form-string`), not JSON.
- **Field length limits:** `Engagement.name` max 300 (dojo/engagement/models.py:45), so `ci/` plus a git branch fits. **`Test.branch_tag` max 150** (dojo/test/models.py:79), so a branch name over 150 chars sent as `branch_tag` returns a **400**. Truncate `branch_tag` to 150 chars (it is metadata only) or omit it for long names. `Test.title` max 255.
- **Lookup filters:** `GET /api/v2/products/?name_exact=` is `iexact` (the plain `name` filter is `icontains`, so never use it). `GET /api/v2/engagements/?product=<id>&name=` is exact, because `name` is in `Meta.fields`. Test filters include `engagement`, `title` and `scan_type`. Finding filters include `test` and `active`.

### Authorization (research item 3)

In 3.x open-source the RBAC roles are **inert stubs**. The rewritten OS model is (dojo/authorization/authorization.py:1-20, 95-140; roles_permissions.py:1-50):
- A superuser can do everything.
- `Action.Delete` and `Action.StaffOnly` require **`is_staff`** (authorization.py:111).
- View, Edit, Add and Import pass for `is_staff`. Otherwise they need `authorized_users` membership up the Product Type to Product chain.
- **Creating a new Product Type** through `auto_create_context` requires `user_has_global_permission(user,"add")`. That means superuser, `is_staff`, or the Django permission `dojo.add_product_type` (api_permissions.py:1327-1333; authorization.py:184-200).

**Minimum token identity for D-11 (one token: import, auto-create and delete):** a dedicated user `ci-importer` (name is illustrative) with **`is_staff=true`, `is_superuser=false`**. A non-staff user can import into products it is a member of, and can create a Product Type only if granted `dojo.add_product_type`. It **cannot** delete engagements. Staff is a **global** bypass: that user can view, edit, import into and delete any engagement in the instance, not only CI ones. The adoption guide must state this, and it must recommend a dedicated instance or user. **dojo-pro** replaces this model with RBAC. Under Pro, check the Pro role matrix before relying on it; that was not researched here.

**Token minting:** `POST /api/v2/api-token-auth/` with `{"username","password"}` returns `{"token": "..."}` (dojo/urls.py:219-228). It is enabled by default. The `dojo_ratelimit` decorator is keyed per IP, but `DD_RATE_LIMITER_ENABLED` defaults to **False** (settings.dist.py:245; rate `5/m` when enabled), so the harness's two token calls per run are unaffected. It refuses accounts that still owe a forced password reset. The initializer creates admin via `create_superuser` without that flag. `POST /api/v2/users/{id}/reset_api_token/` returns **204 with no body**, so it cannot be used to read a token. The header is `Authorization: Token <key>`.

**Password policy for creating the staff user in the harness** (`POST /api/v2/users/`): 9 to 48 characters, with at least one digit, one uppercase letter, one lowercase letter and one symbol, and not a common password (dojo/system_settings/models.py:302-335). The smoke's `gen_secret` is alphanumeric only and would get a **400**.

## Architecture Patterns

### System Architecture Diagram

```
 PR opened/sync/reopened          PR closed                 06:00 America/Toronto
 (pr-security.yml)                (pr-security.yml)          (scheduled-security.yml)
        │                               │                             │
        └──────── uses: security.yml (Mode A local / Mode B @v1) ─────┘
                                        │  secrets: DEFECTDOJO_API_TOKEN (explicit, optional)
                                        │  vars.* resolve to CALLER repo
          ┌─────────────────────────────┼──────────────────────────────┐
          │ event.action != 'closed'    │                              │ event.action == 'closed'
          ▼                             │                              ▼
  5 scan jobs (frozen names) ── artifacts: semgrep-results,     defectdojo-cleanup
  sast iac sca container secrets   checkov-results, sca-results,   if: vars.DEFECTDOJO_URL != ''
          │                        trivy-image-results(opt),       │ gate step: token present?
          │ needs (always())       gitleaks-results                │  no → log reason, skip
          ▼                                                        │  head_ref == default? → refuse
  defectdojo-import                                                ▼
   if: always() && action != 'closed' && vars.DEFECTDOJO_URL != ''  GET products?name_exact → exact match
   gate step: token present? no → "SKIP: ..." and stop             GET engagements?product&name=ci/<head>
   download-artifact pattern '*-results' merge-multiple            client-side exact re-check
   for each known file present:                                    DELETE /engagements/{id}/ → expect 204
     POST /api/v2/reimport-scan/ (multipart, auto_create_context)  GET again → expect 0
       product_type_name, product_name, engagement_name=ci/<branch>,
       test_title=<per-file>, scan_type=<table>
     record HTTP code + test_id + statistics
   verify step (no continue-on-error): every attempted file got 201 → else red
                                        │
                                        ▼
                               DefectDojo (DEFECTDOJO_URL, TLS verified)
```

### Recommended file layout (security-platform)

```
.github/workflows/
├── security.yml                   # + on.workflow_call.secrets.DEFECTDOJO_API_TOKEN (required: false)
│                                  # + job-level `if: github.event.action != 'closed'` on the 5 scan jobs
│                                  # + jobs.defectdojo-import, jobs.defectdojo-cleanup
├── pr-security.yml                # types: [opened, synchronize, reopened, closed]; secrets: pass-through
├── scheduled-security.yml         # NEW caller: schedule (timezone) + workflow_dispatch; job id `security`
└── defectdojo-import-proof.yml    # NEW harness: workflow_dispatch + path-filtered pull_request
scripts/
├── check-workflow-uploads.sh      # EXTEND: scan-job vs side-channel-job split
├── defectdojo-live-smoke.sh       # EXTEND minimally: optional post-hook after all checks pass
└── defectdojo-import-proof.sh     # NEW: mint staff token, extract+run step bodies, assert
```
This repo gets `scripts/check-adoption-guide.sh` (extended), `docs/adr/adr024-...md`, a new row in `docs/adr/README.md`, and a new section in `docs/adoption-guide.md`.

### Pattern 1: Opt-in guard with an optional secret (research items 5 and 6)

The `secrets` context is **not** allowed in `jobs.<id>.if`. The allowed contexts are `github, needs, vars, inputs` [CITED: docs.github.com contexts reference]. Put the `vars` part in the job-level `if` so the job is **skipped** when the URL is unset (D-02). Check the secret in a **gate step** that writes only a boolean to `GITHUB_OUTPUT`, which also logs the reason for D-13. Do **not** put the token in job-level `env`, because every step, including third-party actions, would see it.

```yaml
# security.yml
on:
  workflow_call:
    inputs:
      gate_mode: { ... unchanged ... }
    secrets:
      DEFECTDOJO_API_TOKEN:
        description: DefectDojo API v2 token. Optional; import is skipped when absent.
        required: false

jobs:
  defectdojo-import:
    name: DefectDojo Import
    needs: [sast, iac, sca, container, secrets]
    # always(): scan jobs "fail" by design under blocking; import must still run.
    # vars resolves to the CALLER repo in both Mode A and Mode B.
    if: always() && github.event.action != 'closed' && vars.DEFECTDOJO_URL != ''
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read          # download-artifact of same-run artifacts
    steps:
      - name: Gate — token present?
        id: gate
        env:
          DD_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }}
        run: |
          if [ -z "$DD_TOKEN" ]; then
            echo "SKIP: DEFECTDOJO_API_TOKEN is not available to this run (fork or Dependabot PR, or the secret is unset). Nothing was imported."
            echo "enabled=false" >> "$GITHUB_OUTPUT"
          else
            echo "enabled=true" >> "$GITHUB_OUTPUT"
          fi
```
Why token presence and not the `pull_request.head.repo` guard: `github.event.pull_request` is **null on `schedule`**, so the existing guard evaluates false there and would skip every scheduled import. Fork and Dependabot PRs get no Actions secrets [CITED: docs.github.com events-that-trigger-workflows: "secrets are not passed to the runner when a workflow is triggered from a forked repository"; Dependabot PRs "are treated as though they are from a forked repository"]. Token absence therefore *is* the D-13 condition. It is the same guard family in intent: the check sits on the step and reads the run's capability. Optionally also compound `github.actor != 'dependabot[bot]'` into the gate, so a token accidentally stored as a *Dependabot* secret is still refused.

### Pattern 2: Caller secret pass-through (Mode A and Mode B identical)

```yaml
# pr-security.yml
on:
  pull_request:
    # Listing types REPLACES the default [opened, synchronize, reopened] —
    # all three must be restated or PRs stop being scanned.
    types: [opened, synchronize, reopened, closed]
jobs:
  security:                 # FROZEN id and name
    name: security
    permissions: { contents: read, security-events: write, actions: read }
    uses: ./.github/workflows/security.yml     # Mode B: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1
    secrets:
      DEFECTDOJO_API_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }}   # explicit, never `inherit` (D-12)
```
An unset caller secret passes an empty string, and the gate step turns that into a clean skip. `vars.DEFECTDOJO_*` is **not** passed in `with:`. The callee reads `vars` directly: "For reusable workflows, the variables from the caller workflow's repository are used" [CITED: docs.github.com/en/actions/reference/workflows-and-actions/variables]. This mirrors the existing `GATE_MODE` design and its prohibition on bare `vars` passthroughs.

### Pattern 3: Skip the five scan jobs on `closed` without renaming them (research item 5)

Add `if: github.event.action != 'closed'` at **job level** to `sast`, `iac`, `sca`, `container` and `secrets`. On `schedule` and `workflow_dispatch`, `github.event.action` is empty, so the scan jobs run. In a called workflow the `github` context is the caller's [CITED: reusing-workflow-configurations], so `github.event.action` is the PR action. The job ids and `name:` values are unchanged, so the five contexts are unchanged. A skipped job "will report its status as 'Success'... even if it is a required check" [CITED: docs.github.com status checks]. That is harmless on a closed PR, but see Pitfall 8.

### Pattern 4: Cleanup job with the D-10 exact-name guard

```yaml
  defectdojo-cleanup:
    name: DefectDojo Cleanup
    if: github.event_name == 'pull_request' && github.event.action == 'closed' && vars.DEFECTDOJO_URL != ''
    runs-on: ubuntu-latest
    permissions: { contents: read }
    steps:
      - name: Gate — token present?
        id: gate
        env: { DD_TOKEN: "${{ secrets.DEFECTDOJO_API_TOKEN }}" }
        run: ...same as import...
      - name: Delete ci/<head-branch> engagement
        id: delete
        if: steps.gate.outputs.enabled == 'true'
        continue-on-error: true          # ADR-001 side-channel carve-out (D-03)
        env:
          DD_URL: ${{ vars.DEFECTDOJO_URL }}
          DD_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }}
          DD_PRODUCT: ${{ vars.DEFECTDOJO_PRODUCT || github.repository }}
          HEAD_REF: ${{ github.head_ref }}                          # attacker-controlled: env only
          DEFAULT_BRANCH: ${{ github.event.repository.default_branch }}
        run: |
          python3 - <<'PY'
          # 1. refuse if HEAD_REF is empty or == DEFAULT_BRANCH
          # 2. target = "ci/" + HEAD_REF ; never a pattern
          # 3. GET /api/v2/products/?name_exact=<urlencoded>  -> keep results whose name == DD_PRODUCT exactly; require exactly 1
          # 4. GET /api/v2/engagements/?product=<id>&name=<urlencoded target>&limit=100
          #    -> keep results whose name == target AND product == id; 0 => "nothing to delete", exit 0
          # 5. for each exact match: DELETE /api/v2/engagements/<id>/ ; require 204
          # 6. re-GET: require 0 remaining; write outcome to a file for the verify step
          PY
      - name: Verify cleanup landed
        if: steps.gate.outputs.enabled == 'true'
        run: |
          if [ "${{ steps.delete.outcome }}" != "success" ]; then echo "..."; exit 1; fi
```
Engagement names are not unique, because the server takes "last" on lookup. Deleting **every exact-name match inside the resolved product** stays within D-10: it is still that branch's engagement and no pattern is involved. The planner may choose to refuse more than one match instead, but that leaves orphans after a race. On a merged PR `github.head_ref` is still populated, so the delete runs the same way for merged and abandoned PRs.

### Pattern 5: The import loop, one step with an explicit file table

Download: `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` with `pattern: '*-results'`, `merge-multiple: true`, `path: dd-reports`. The five names all end in `-results`, and every report filename is unique across artifacts, so a flat merge is safe. Pattern mode with zero matches does not throw. `name:` mode throws "Artifact 'x' not found", which would break on a Dockerfile-free repo [VERIFIED: download-artifact@v8.0.1 src/download-artifact.ts:88-96,157-200]. Without `merge-multiple`, a *single* match is extracted without a subdirectory while several matches get one subdirectory each, so the layout would change with the match count.

Then one `python3` step, not bash string-building, iterates a **static table** of (glob, scan_type, title template) and calls `curl` once per file via `subprocess`, or uses `urllib.request` with a hand-built multipart body. Using `curl` keeps D-04 literal. Recommended table:

| Glob in `dd-reports/` | scan_type | test_title |
|---|---|---|
| `semgrep-results.json` | `Semgrep JSON Report` | `semgrep` |
| `checkov-results.json` | `Checkov Scan` | `checkov` |
| `trivy-fs.json` | `Trivy Scan` | `trivy-fs` |
| `trivy-image.json` | `Trivy Scan` | `trivy-image` |
| `gitleaks-results.json` | `Gitleaks Scan` | `gitleaks` |
| `npm-audit-*.json` | `NPM Audit v7+ Scan` | `npm-audit-<N>` (from filename) |
| `pip-audit-*.json` | `pip-audit Scan` | `pip-audit-<N>` (from filename) |
| `tflint.sarif` | `SARIF` | `tflint` |

An absent file (no Dockerfile, no lockfile) prints `SKIP: <file> not in artifacts — <reason>` and is not attempted. This is Criterion 4 skip honesty. Record every attempted file with its HTTP code, `test_id` and `statistics` in a JSON results file. The following verify step, which has no `continue-on-error`, fails red unless **every attempted file returned 201 with a `test_id`**. It prints a per-file line with `after.total.total` so the log carries the counts.

Per-call form. The token goes through a header file, never argv. All values come from env, and none are interpolated with `${{ }}` into `run:`:
```bash
curl -sS --fail-with-body -o resp.json -w '%{http_code}' \
  ${CURL_TLS_ARGS} \
  -H @"$HDR_FILE" \                         # file contains: Authorization: Token <key>
  -F "scan_type=${SCAN_TYPE}" -F "file=@${FILE}" \
  -F "product_type_name=${DD_PRODUCT_TYPE}" -F "product_name=${DD_PRODUCT}" \
  -F "engagement_name=ci/${BRANCH}" -F "test_title=${TITLE}" \
  -F "auto_create_context=true" -F "close_old_findings=true" \
  -F "branch_tag=${BRANCH}" -F "commit_hash=${GITHUB_SHA}" -F "build_id=${GITHUB_RUN_ID}" \
  -F "source_code_management_uri=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" \
  "${DD_URL%/}/api/v2/reimport-scan/"
```
`-H @file` reads headers from a file [VERIFIED: `curl --help all` shows `-H, --header <header/@file>`; available since curl 7.55; ubuntu-24.04 ships curl 8.5]. When the step is written in Python, pass the header through `subprocess` with `-H @file` as well. Watch `-F` value escaping: curl's `-F name=value` treats a leading `@` or `<` in *value* as a file reference. A branch name such as `@evil` would make curl read a file. Use `--form-string` for every non-file field.

Branch resolution: `BRANCH = GITHUB_HEAD_REF if GITHUB_EVENT_NAME == 'pull_request' else GITHUB_REF_NAME`. On schedule, `GITHUB_REF` is the default branch [CITED: events-that-trigger-workflows]. Use the runner-provided `GITHUB_*` env vars. They are not `${{ }}` interpolation, so there is no injection surface.

### Pattern 6: Scheduled caller (research item 4)

```yaml
# scheduled-security.yml
name: Scheduled Security
on:
  schedule:
    - cron: '0 6 * * *'
      timezone: "America/Toronto"     # IANA; DST handled by GitHub
  workflow_dispatch: {}
permissions:
  contents: read
jobs:
  security:
    name: security
    permissions: { contents: read, security-events: write, actions: read }
    uses: ./.github/workflows/security.yml
    secrets:
      DEFECTDOJO_API_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }}
```
Verified: "By default, scheduled workflows run in UTC. You can optionally specify a timezone using an IANA timezone string", and at spring-forward "scheduled workflows in skipped hours advance to the next valid time" [CITED: docs.github.com workflow-syntax `on.schedule`; GitHub changelog 2026-03-19 "Improvement", not preview]. 06:00 is never a skipped hour in America/Toronto, where the transition is at 02:00. Local `actionlint` 1.7.12 accepts the key (measured: exit 0). The job id `security` gives check runs named `security / ...` on the default-branch commit. That is harmless, but a different job id (for example `scheduled`) avoids clutter; choose one and document it. It does not affect required checks, which are evaluated on PRs.

### Pattern 7: Harness — run the committed step bodies (research items 7 and 8)

The kind cluster can be reached only from the runner that created it. A job that calls `uses: ./.github/workflows/security.yml` runs the callee's jobs on **other** runners, so the proof cannot be done by calling the workflow with `DEFECTDOJO_URL` set. Use a two-job test workflow:

```yaml
# defectdojo-import-proof.yml
on:
  workflow_dispatch: {}
  pull_request:
    paths:
      - .github/workflows/security.yml
      - .github/workflows/pr-security.yml
      - .github/workflows/scheduled-security.yml
      - .github/workflows/defectdojo-import-proof.yml
      - scripts/defectdojo-import-proof.sh
      - scripts/defectdojo-live-smoke.sh
      - kubernetes/defectdojo/**
permissions: { contents: read }
jobs:
  scans:                                   # NOT `security` — avoid colliding with the frozen contexts
    permissions: { contents: read, security-events: write, actions: read }
    uses: ./.github/workflows/security.yml  # real scanners on fixtures/; import skipped (security-platform sets no DEFECTDOJO_URL)
  prove-import:
    needs: scans
    if: always()
    runs-on: ubuntu-latest
    permissions: { contents: read, actions: read }
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1   # v7.0.1
      - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c  # v8.0.1
        with: { pattern: '*-results', merge-multiple: true, path: dd-reports }
      - name: Install Helm v4.3.0 (download + sha256)
        run: ...
      - name: Live proof
        run: bash scripts/defectdojo-import-proof.sh dd-reports
```
Caveat: a `pull_request`-triggered proof workflow in security-platform also creates `scans / SAST — ...` check runs. They are not required contexts, but they are an extra five checks on PRs that touch those paths. This is acceptable. The alternative is to have `prove-import` run the scanners itself, which duplicates install logic, so it is not recommended.

`scripts/defectdojo-import-proof.sh`:
1. **Reuse the smoke for bring-up.** Add a minimal, additive post-hook to `defectdojo-live-smoke.sh`, for example `DD_SMOKE_POST_HOOK=<script>`. It runs after `print_summary` would report ALL PASS and before the EXIT trap tears down. It exports `BASE_URL`, the CA path, the admin password file and `KIND_CONTEXT`. Nothing changes when the variable is unset. Alternatively the proof script can own a copy of the bring-up, but that duplicates about 400 lines. The post-hook is the smaller change, and Phase 26's evidence path is untouched when it is unset.
2. **Host resolution without `--resolve`:** run `echo "127.0.0.1 defectdojo.smoke.test" | sudo tee -a /etc/hosts` on the runner, then `DEFECTDOJO_URL=https://defectdojo.smoke.test:18443`. The committed step body then needs no harness-only branch. The smoke's port-forward stays on 18443.
3. **Mint a least-privilege token.** Get an admin token from `/api/v2/api-token-auth/`, reading the admin password from its file into a JSON body file, never argv. `POST /api/v2/users/` a `ci-importer` with `is_staff=true`, `is_superuser=false` and a **policy-compliant** password: append a fixed class-complete suffix to a random base, 9 to 48 chars total. Then call `/api/v2/api-token-auth/` as `ci-importer`. The proof therefore exercises the documented minimum permission set, not superuser.
4. **Extract and run the committed bodies:** use PyYAML to load `.github/workflows/security.yml`, then select `jobs['defectdojo-import'].steps[id==<import-step-id>].run` and the cleanup step likewise. Write each to a temp file and run it with `bash -e <file>`. This is the runner default for an unspecified shell, and the technique is `check-detector-parity.sh`'s. Supply the same env names the workflow maps: `DD_URL`, `DD_TOKEN`, `DD_PRODUCT`, `DD_PRODUCT_TYPE`, the CA variable, `GITHUB_EVENT_NAME`, `GITHUB_HEAD_REF` and so on. The body must therefore reference only env, never `${{ }}`. **This is a design constraint on the step body.** Any `${{ }}` left in the body would be passed through literally and break the proof, so the extractor should fail on a `${{` substring in the body.
5. **Assertions** (see Validation Architecture for the exact list).

**CA bundle (D-18, discretion): recommend an optional caller variable `DEFECTDOJO_CA_CERT`** containing PEM text. The step writes it to a file and adds `--cacert <file>`. The harness sets it to the kind CA, so **the harness tests exactly the consumer-facing verified path**, and Phase 29's homelab (private CA) gets a secure option other than `DEFECTDOJO_INSECURE`. When both are set, INSECURE wins and the warning fires; alternatively, fail. Choose one and document it. Note that `--cacert` replaces the system trust store for that call, which is correct for a private CA.

### Anti-Patterns to Avoid
- **`${{ github.head_ref }}` (or any `${{ github.event.* }}`) inside `run:`.** This is script injection, because branch names can contain `$()`, backticks and `;`. Semgrep `p/default` on security-platform's own PRs will also flag it. Pass values through `env:`.
- **Token on argv** (`-H "Authorization: Token $T"` is visible in `ps` on the runner). Use a header file or stdin.
- **`curl -F key=value` for branch- or product-derived values.** A leading `@` or `<` makes curl read a file. Use `--form-string`.
- **Job-level `env:` holding the secret.** It leaks into third-party action steps.
- **Reusing `github.event.pull_request.head.repo.full_name == github.repository` on the new jobs.** It is false on `schedule`, so scheduled imports would never run.
- **Reimport without `test_title`.** Trivy fs and image would cross-update the same Test.
- **`GET /products/?name=`.** It is `icontains`, so `acme/api` also matches `acme/api-v2`.
- **`import-scan` on each run.** It creates a new Test per run, so findings pile up (violates D-07).
- **Hand-counting "expected findings" by re-implementing parser logic.** See Pitfall 6.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Get-or-create of product type, product, engagement and test | Pre-query + POST chains | `reimport-scan` + `auto_create_context=true` | Server does it under `select_for_update` with race handling (auto_create_context.py:233-340) |
| Close fixed findings | Diff logic in CI | `close_old_findings=true` (reimport default) | Test-scoped closing is built in |
| Report normalisation | Converting to SARIF or generic | Native parsers (D-08) | Loses fidelity; RETENTION FORMAT contract |
| Artifact fetching | `gh api` artifact zip download | `actions/download-artifact` v8.0.1 | Digest verification, pattern mode |
| URL encoding of branch names in queries | String concatenation | `urllib.parse.urlencode` (python3) or `curl -G --data-urlencode` | `/`, `#`, `&`, `+` in branch names |
| Multipart bodies | Manual boundary strings | `curl --form-string` / `-F file=@` | Correctness |

## Common Pitfalls

### Pitfall 1: Both offline gates go red the moment a job is added
**What goes wrong:** `check-workflow-uploads.sh` JOB-SHAPE asserts `len(callee_jobs) == 5`, no job has `needs:`, and the ordered name list equals `FROZEN_JOB_NAMES`. `check-adoption-guide.sh` asserts exactly 5 callee job names, exactly 1 caller job name, and no `security / ...` string in the guide beyond the derived five (SIXTH-CONTEXT).
**How to avoid:** Extend both gates deliberately, in the same PR:
- "Scan jobs" means the frozen five job **ids** (`sast iac sca container secrets`). They must exist, stay needs-free, keep their names in order, and are the only source of derived contexts.
- An explicit allow-list (`defectdojo-import`, `defectdojo-cleanup`) may carry `needs:` and must **not** be in `set-required-checks.sh`.
- Any other job is still a failure.

The adoption-guide gate should filter by the same five ids, not "all named jobs". If the pr-security caller keeps one job, leave its check at 1. The new guide section must not write literal `security / DefectDojo Import` strings, or SIXTH-CONTEXT fires. Refer to "the import job" in prose.
**Warning signs:** a gate that passes only because a new job has no `name:`. The adoption gate's `if n` filter drops unnamed jobs, but the uploads gate does not. Don't rely on that accident.

### Pitfall 2: `types:` replaces the default activity set
Writing `types: [closed]` makes PRs stop being scanned, and every required context sits pending. The line must be `[opened, synchronize, reopened, closed]` [CITED: events-that-trigger-workflows: default is opened, synchronize, reopened].

### Pitfall 3: Import silently never runs on schedule
Caused by reusing the pull_request-shaped guard. Use token presence, as in Pattern 1.

### Pitfall 4: Existing verify steps skip on `schedule`
The 11 existing verify steps (6 SARIF, 5 artifact) carry `github.event.pull_request.head.repo.full_name == github.repository`, which is null on schedule. They **skip, not fail**, so a scheduled run cannot detect a failed SARIF or artifact upload. This is not a correctness regression, because nothing turns falsely red. It is a blind spot the new schedule introduces. A minimal fix is to compound `github.event_name == 'schedule' || (...)` into each guard, but that touches all five scan jobs, which D-01 restricts. **Recommendation:** document it in ADR-024 as a known gap and leave the scan jobs alone unless the operator opts in. The import job's own verify step does run on schedule.

### Pitfall 5: Product Type drift gives a 400 on every import
If the product exists under a different Product Type (someone moved it in the UI, or `DEFECTDOJO_PRODUCT_TYPE` changed), `get_target_product_if_exists` raises and the import returns **400**. Document it in the adoption guide: "set `DEFECTDOJO_PRODUCT_TYPE` once; changing it later requires moving the product back or renaming".

### Pitfall 6: "Counts match the artifact contents" is not raw-entry equality
The Semgrep (title+path+line), Gitleaks (hash), NPM Audit v7+ (title+severity) and SARIF (`drop_repeated_unique_ids`) parsers merge entries, so the DefectDojo count can be lower than the raw count. Checkov (`failed_checks`), Trivy (`Results[].Vulnerabilities`) and pip-audit (`dependencies[].vulns`) do not merge. Also, on reimport, two report entries with the same hash_code match one existing finding, and the other existing twin can be closed. Active counts can drop on run 2 while the total stays the same.
**How to avoid (assertion design):**
- (a) Run 1: for every file, `statistics.after.total.total` equals `GET /findings/?test=<id>` `count`. This is internal consistency.
- (b) Run 1: exact equality to the raw count **only** for checkov, trivy-fs, trivy-image and pip-audit. For semgrep, gitleaks, npm and SARIF, assert `1 ≤ count ≤ raw` when raw > 0, and `count == 0` when raw == 0.
- (c) Run 2, the same files reimported: `statistics.delta.created.total.total == 0` for every file, `after.total.total` equals run 1's value, and the number of Tests in the engagement is unchanged. This is the precise "no duplicates" statement.

Measure on the first live run and record the observed numbers in the SUMMARY.

### Pitfall 7: Mode A consumers have no `scripts/`
Any design that runs `bash scripts/...` from `security.yml` breaks Mode A, which copies three files, and forces the callee to check out security-platform in Mode B. Keep the logic inline (Pattern 7).

### Pitfall 8: A closed PR's head SHA gets "skipped" versions of the five required contexts
The `closed` run creates the five check runs as skipped, which counts as success. If a PR is reopened, the `reopened` run supersedes them once it queues. There is a small theoretical window in which the latest check runs on the head SHA are the skipped ones [ASSUMED: check runs of a `pull_request` run attach to the PR head SHA; confirm in the live proof by listing check runs on the head SHA after a close]. The risk is LOW: exploiting it needs close, reopen and merge before the reopen run's jobs are queued. Record it in ADR-024. The zero-risk alternative is a separate caller file for `closed` with a different job id, but that conflicts with D-15's wording, so raise it with the operator only if the live check shows a real window.

### Pitfall 9: Race between an in-flight import and the PR-close delete
A slow import on the final push can finish after the cleanup and re-create `ci/<branch>`. Mitigate with job-level `concurrency: { group: defectdojo-${{ github.repository }}-${{ github.head_ref || github.ref_name }}, cancel-in-progress: false }` on both side-channel jobs. MEDIUM confidence: a newer *pending* run in a group cancels an older *pending* one. That is acceptable for imports; for cleanup, only a reopen could queue after it.

### Pitfall 10: Harness user password rejected
`gen_secret` output is alphanumeric only, so `POST /users/` returns 400. See the authorization section above.

### Pitfall 11: Helm 3 on ubuntu-latest
The runner ships Helm 3.22.0. The smoke's `--wait` semantics were measured only on Helm v4.3.0. Install v4.3.0 as shown in the Standard Stack.

### Pitfall 12: Scheduled workflows auto-disable
"In a public repository, scheduled workflows are automatically disabled when no repository activity has occurred in 60 days" [CITED: events-that-trigger-workflows]. Put this in the adoption guide.

### Pitfall 13a: Mode B consumers must edit their own caller file
In Mode B, `pr-security.yml` lives in the **consumer** repository. Moving `v1` gives them the new `security.yml`, but the `closed` type and the `secrets:` pass-through are caller-side edits the consumer must make. Without them, import is skipped because the token is empty, and cleanup never fires. That is safe, because old callers keep working per D-16, but it is not automatic. The adoption-guide section must show the updated caller block for both modes, plus the optional `scheduled-security.yml`.

### Pitfall 13: Dependabot and the new action
Adding `actions/download-artifact` to `security.yml` means Dependabot will bump it. The existing `dependabot.yml` covers github-actions, so no change is needed. The `check-workflow-uploads.sh` SHA-PIN check covers job-level and step-level `uses:` in the two files it parses. **Extend it to also parse `scheduled-security.yml` and `defectdojo-import-proof.yml`**, or glob `.github/workflows/*.yml`.

## Code Examples

### Engagement delete guard (python3, stdlib only; token via env, TLS args via env)
```python
# Source: pattern derived from dojo/engagement/api/filters.py (name exact) and
# dojo/product/api/filters.py (name_exact = iexact) @3.3.200
import json, os, subprocess, sys, urllib.parse
url = os.environ["DD_URL"].rstrip("/")
head = os.environ.get("HEAD_REF", "")
default = os.environ["DEFAULT_BRANCH"]
product = os.environ["DD_PRODUCT"]
if not head or head == default:
    print(f"REFUSE: head_ref {head!r} is empty or the default branch; nothing deleted"); sys.exit(0)
target = "ci/" + head
def api(method, path, expect):
    out = subprocess.run(["curl", "-sS", "-X", method, "-H", "@" + os.environ["HDR_FILE"],
                          *os.environ.get("CURL_TLS_ARGS", "").split(),
                          "-o", "/tmp/r.json", "-w", "%{http_code}", url + path],
                         capture_output=True, text=True)
    code = out.stdout.strip()
    if code != expect:
        print(f"{method} {path} -> {code} (expected {expect}): {out.stderr}"); sys.exit(1)
    return json.load(open("/tmp/r.json")) if expect == "200" else None
q = urllib.parse.urlencode({"name_exact": product, "limit": 100})
prods = [p for p in api("GET", f"/api/v2/products/?{q}", "200")["results"] if p["name"] == product]
if len(prods) != 1:
    print(f"no single exact product {product!r} (found {len(prods)}); nothing deleted"); sys.exit(0)
pid = prods[0]["id"]
q = urllib.parse.urlencode({"product": pid, "name": target, "limit": 100})
engs = [e for e in api("GET", f"/api/v2/engagements/?{q}", "200")["results"]
        if e["name"] == target and e["product"] == pid]
if not engs:
    print(f"nothing to delete: no engagement {target!r} in product {pid}"); sys.exit(0)
for e in engs:
    api("DELETE", f"/api/v2/engagements/{e['id']}/", "204")
    print(f"deleted engagement id={e['id']} name={target!r} product={pid}")
```
Illustrative only. The planner owns the final shape, including writing the header file with `umask 077` and removing it afterwards.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UTC-only cron + manual DST shift | `schedule[].timezone` (IANA) | GitHub changelog 2026-03-19 | D-14 needs no drift note |
| DefectDojo OS RBAC roles (Reader/Writer/Maintainer/Owner/API_Importer) | OS: superuser / staff / `authorized_users`; RBAC moved to dojo-pro | DefectDojo 3.x ("Track B" legacy authorization rewrite, dojo/authorization/MIGRATION_REHEARSAL.md) | Docs and blog posts recommending "API_Importer role" are wrong for OS 3.3.200; the minimum is `is_staff` |
| Reusable workflow cannot learn its own repo/sha | `job.workflow_repository` / `job.workflow_sha` / `job.workflow_ref` / `job.workflow_file_path` | GitHub changelog 2026-09-03 | Would let Mode B check out callee scripts; not used here because Mode A has no scripts |
| DefectDojo reimport requires an existing Test | Reimport with `auto_create_context` falls back to import | pre-3.x (current in 3.3.200) | Single endpoint for all runs |

**Deprecated/outdated:**
- The `"TFLint Scan"` parser exists but reads JSON, not SARIF, so it does not apply until the scan job emits `--format json`.
- Semgrep and Gitleaks SARIF imports: native JSON is preferred per D-08.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A2 | Check runs from a `pull_request: closed` run attach to the PR head SHA | Pitfall 8 | If they attach to the merge commit, the reopen window does not exist (risk goes down) |
| A3 | Job-level `concurrency` in a called workflow serializes across separate caller runs as documented for normal workflows | Pitfall 9 | Rare race re-creates a deleted PR engagement; cosmetic |
| A4 | A kind cluster with DefectDojo, cert-manager and ingress-nginx fits on ubuntu-latest (4 vCPU / 16 GB public) within about 20 min | Pattern 7 | Proof job slow or OOM; smoke measured 10-20 min cold locally, not yet on a hosted runner |
| A5 | dojo-pro deployments have a different minimum-permission answer | Authorization | Only matters if the operator runs Pro |
| A6 | GitHub `github.event.action` is empty on `schedule`/`workflow_dispatch` in a called workflow | Pattern 3 | If non-empty but != 'closed', behaviour is still correct |

## Open Questions

1. **Delete one match or all exact matches?**
   - Known: engagement names are not unique, and auto-create reuses the last match, so duplicates arise only from races.
   - Recommendation: delete every exact-name match inside the resolved product and log each id. It satisfies D-10: no pattern, not the default branch.
2. **Should the five scan jobs' verify guards gain a `schedule` arm?** (Pitfall 4)
   - Recommendation: no in this phase. Record the gap in ADR-024 and let the operator decide.
3. **Numbered `npm-audit-N.json` titles drift when a lockfile is added.**
   - Known: numbering follows `git ls-files` order, and the mapping file `npm-lockfiles.txt` is not in the artifact.
   - Effect: adding a lockfile shifts titles, so `npm-audit-2` then holds a different lockfile's findings. `close_old_findings` keeps each Test self-consistent, but history is attributed to the wrong lockfile.
   - Recommendation: accept this and document it. Fixing it means adding the list file to the `sca-results` artifact (a scan-job change, deferred).
4. **`deduplication_on_engagement` is fixed when the engagement is created.** It is read only in `get_or_create_engagement` (auto_create_context.py). Sending it on later reimports has no effect. Hand-forward to Phase 28: changing it on existing `ci/*` engagements needs `PATCH /api/v2/engagements/{id}/`, or deleting and re-creating them. Recommendation for this phase: omit it, so the server default False applies, and let Phase 28 decide.
5. **Phase 29 side effect.** Once security-platform itself sets `DEFECTDOJO_URL` and the secret, the proof workflow's `scans` job, which calls `security.yml`, will also import into the real instance under `ci/<branch>`. This is harmless but may surprise; note it in ADR-024 or the Phase 29 context.
6. **Product Type default string.** Recommend `CI`. It is short, and a Product Type is a grouping; the engagement type is already `CI/CD`.
7. **Scheduled caller job id.** Recommend `security`, which keeps the adoption-guide single-caller logic simple. `scheduled` is also fine; either way the gate only reads `pr-security.yml`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| gh CLI | tag/release, run inspection | ✓ (local) | 2.101.0 | — |
| actionlint | offline workflow lint (recommend running in the phase gate) | ✓ (local) | 1.7.12 (accepts `timezone:`; measured) | not in pre-commit; run manually |
| yamllint | pre-commit (`-d relaxed`) | ✓ | — | — |
| python3 + PyYAML | gates, harness extractor | ✓ | pyenv | gates exit 2 if missing |
| kind / kubectl / helm (local) | local run of proof script | ✓ | kind 0.33.0, kubectl 1.37.1, Helm v4.3.0 | — |
| Docker (local) | kind | ✓ (kindest/node images cached) | — | — |
| kind / kubectl on ubuntu-latest | CI proof | ✓ preinstalled | 0.33.0 / 1.37.0 | — |
| Helm v4 on ubuntu-latest | CI proof | ✗ (3.22.0 shipped) | — | download + sha256 v4.3.0 |
| A live DefectDojo reachable by hosted runners | real consumer imports | ✗ | — | out of scope (Phase 29, D-17); proof uses the in-runner kind instance |

**Missing dependencies with no fallback:** none for this phase.
**Missing dependencies with fallback:** Helm v4 on hosted runners (install step).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash + inline python3 gates (project convention, 0/1/2 exit contract) + live GitHub Actions run |
| Config file | none. The gates are self-contained scripts |
| Quick run command | `bash repos/security-platform/scripts/check-workflow-uploads.sh && bash scripts/check-adoption-guide.sh && (cd repos/security-platform && actionlint)` |
| Full suite command | the quick run plus `bash repos/security-platform/scripts/check-detector-parity.sh`, plus `bash repos/security-platform/scripts/defectdojo-import-proof.sh` (local kind, about 15-20 min), plus the `defectdojo-import-proof.yml` run on GitHub via `gh workflow run` then `gh run watch` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DDOJO-02 | Workflow shape: 5 frozen scan jobs unchanged in name/order, needs-free; import/cleanup allow-listed; secret declared optional; SHA pins in all workflow files | static | `bash scripts/check-workflow-uploads.sh` (extended) | ✅ needs extension |
| DDOJO-02 | Adoption guide still lists exactly the 5 contexts; new section present; no sixth `security / ...` string | static | `bash scripts/check-adoption-guide.sh` (extended to filter by the 5 ids) | ✅ needs extension |
| DDOJO-02 | Workflow syntax incl. `timezone:`, `secrets:` in `workflow_call`, job-level `if` contexts | static | `actionlint` in repos/security-platform | ✅ tool present |
| DDOJO-02 | Step bodies contain no `${{` (extractable) and reference only env | static | assertion inside `defectdojo-import-proof.sh` extractor (or a new check in the uploads gate) | ❌ Wave 0 |
| DDOJO-02 | Run 1: product `name == DD_PRODUCT`, product type, engagement `ci/<branch>`, exactly one Test per present report file with expected `scan_type` + `title` | live | `defectdojo-import-proof.sh` | ❌ Wave 0 |
| DDOJO-02 | Run 1 counts: `after.total.total` == `GET /findings/?test=` count; exact raw equality for checkov/trivy-fs/trivy-image/pip-audit; bounded for semgrep/gitleaks/npm/SARIF | live | same | ❌ Wave 0 |
| DDOJO-02 | Run 2 reimport: `delta.created.total.total == 0` per file; totals unchanged; Test count unchanged | live | same | ❌ Wave 0 |
| DDOJO-02 | Cleanup: create a second engagement `ci/<other>` (via reimport with a different branch), run the extracted cleanup body with `HEAD_REF=<other>`, and assert `ci/<other>` is gone (GET returns 0) and `ci/<branch>` survives with the same Test count. Also run it with `HEAD_REF=<default>` and assert REFUSE and nothing deleted. Also run it with a non-existent branch and assert "nothing to delete" and exit 0 | live | same | ❌ Wave 0 |
| DDOJO-02 | Token is staff, not superuser (minimum set proven) | live | same (assert `GET /api/v2/users/?username=ci-importer` → `is_staff:true,is_superuser:false`) | ❌ Wave 0 |
| DDOJO-02 | TLS verified: no `-k` anywhere in proof path; `DEFECTDOJO_INSECURE` unset; CA variable used | live + static | grep in proof script + ssl_verify_result assertion | ❌ Wave 0 |
| DDOJO-02 | Opt-out regression: with `DEFECTDOJO_URL` unset the import and cleanup jobs are skipped and the 5 checks are unchanged | live (GitHub) | the proof workflow's `scans` job itself (security-platform sets no URL), then `gh api .../check-runs` shows the import job as `skipped` | ✅ implicit |
| DDOJO-02 | Real Actions run green | live (GitHub) | `gh workflow run defectdojo-import-proof.yml` then `gh run watch --exit-status` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** the quick run command (three static gates, seconds).
- **Per wave merge:** add `check-detector-parity.sh` and a local `defectdojo-import-proof.sh` when kind is available.
- **Phase gate:** the GitHub Actions proof run is green, with its run id recorded, before `/gsd:verify-work`, and both gates are green on the final tree.

### Wave 0 Gaps
- [ ] Extend `scripts/check-workflow-uploads.sh`: split the JOB-SHAPE check into scan jobs and side-channel jobs, and extend SHA-PIN to all workflow files.
- [ ] Extend `scripts/check-adoption-guide.sh`: derive contexts from the five scan-job ids only.
- [ ] `scripts/defectdojo-import-proof.sh`: token minting, extractor, assertions.
- [ ] Add a minimal post-hook to `scripts/defectdojo-live-smoke.sh`, or document a standalone bring-up.
- [ ] `.github/workflows/defectdojo-import-proof.yml`.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | DefectDojo API token (`Authorization: Token`), declared optional `workflow_call` secret, explicit pass (no `inherit`); header via file, never argv; harness mints per-run token for a per-run user |
| V3 Session Management | no | Token auth only; no sessions |
| V4 Access Control | yes | Dedicated `is_staff`, non-superuser identity (the minimum for delete and new Product Type at 3.3.200 OS); documented that staff is instance-wide; import/cleanup never required checks; job `permissions` least-privilege (`contents: read`, `actions: read`) |
| V5 Input Validation | yes | `github.head_ref`/product names through `env:` only; `--form-string` for non-file fields; `urllib.parse.urlencode` for queries; client-side exact equality re-check before DELETE; default-branch refusal |
| V6 Cryptography | yes | TLS verified by default; `--cacert` for private CA (`DEFECTDOJO_CA_CERT`); `-k` only under `DEFECTDOJO_INSECURE=true` with a `::warning::` every run; never hand-roll |
| V7 Error handling / logging | yes | Never print the token; `set -x` never used; response bodies may echo filenames, but DefectDojo does not echo tokens |
| V14 Configuration | yes | SHA-pinned actions (ADR-004); Helm binary sha256-verified |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Script injection via branch name (`${{ github.head_ref }}` in `run:`) | Tampering / Elevation | env-only passing; Semgrep p/default already flags the pattern on security-platform PRs |
| curl `-F` value starting with `@`/`<` reads a runner file and uploads it | Information disclosure | `--form-string` for every non-file field |
| Token exfiltration by a fork PR | Information disclosure | Secrets are not passed to fork/Dependabot runs; token-presence gate; `pull_request` (not `pull_request_target`) trigger kept |
| Over-broad delete (wrong engagement, default branch, pattern) | Tampering / DoS | exact product (`name_exact` + client `==`), exact engagement name + product id re-check, default-branch refusal, 404-safe |
| Token leak into third-party action env | Information disclosure | step-scoped `env:` only on the steps that call DefectDojo |
| MITM with `-k` | Spoofing | verified TLS default; INSECURE opt-in with a per-run warning; the proof never uses `-k` |
| Staff token compromise = full-instance write | Elevation | document it; recommend a dedicated DefectDojo instance/user; rotate via `reset_api_token` (superuser) |

## Sources

### Primary (HIGH confidence)
- `DefectDojo/django-DefectDojo` @ tag `3.3.200` (cloned 2026-09-25): dojo/tools/{semgrep,checkov,trivy,gitleaks,npm_audit_7_plus,pip_audit,sarif,tflint}/parser.py; dojo/api_v2/serializers.py; dojo/importers/{auto_create_context,base_importer,default_importer}.py; dojo/authorization/{authorization,api_permissions,roles_permissions}.py and MIGRATION_REHEARSAL.md; dojo/engagement/api/{views,filters}.py; dojo/product/api/filters.py; dojo/test/api/filters.py; dojo/finding/api/filters.py; dojo/settings/settings.dist.py; dojo/system_settings/models.py; dojo/user/{api/views,api/serializer,authentication,models}.py; dojo/urls.py; dojo/management/commands/complete_initialization.py
- `actions/download-artifact` @ v8.0.1 source (`src/download-artifact.ts`, `action.yml`)
- Local repo: `repos/security-platform/.github/workflows/{security,pr-security}.yml`, `scripts/{check-workflow-uploads,check-detector-parity,defectdojo-live-smoke,set-required-checks}.sh`, `kubernetes/defectdojo/*` (vendored chart 1.9.53, appVersion 3.3.200); `scripts/check-adoption-guide.sh`, `docs/adoption-guide.md`
- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax (`on.schedule` timezone, DST)
- https://github.blog/changelog/2026-03-19-github-actions-late-march-2026-updates/ (timezone GA)
- https://docs.github.com/en/actions/reference/workflows-and-actions/contexts (`jobs.<id>.if` contexts; `job.workflow_*`)
- https://docs.github.com/en/actions/reference/workflows-and-actions/variables (caller-repo vars in reusable workflows)
- https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations (github context is caller's)
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows (pull_request default types, fork/Dependabot secrets, schedule 60-day disable, GITHUB_REF on schedule)
- https://docs.github.com/en/pull-requests/reference/status-checks (skipped = success for required checks)
- actions/runner-images Ubuntu2404-Readme.md / Ubuntu2604-Readme.md (kind, kubectl, Helm versions); get.helm.sh sha256sum

### Secondary (MEDIUM confidence)
- GitHub changelog "Early September 2026 updates" (job.workflow_* contexts), via search result and docs cross-check
- Local measurement: actionlint 1.7.12 accepts `schedule[].timezone` and `workflow_call.secrets.*.required: false`

### Tertiary (LOW confidence)
- None relied upon.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH. Versions and SHAs were read from the GitHub API and the pinned source.
- DefectDojo API behaviour and authorization: HIGH. Read from the `3.3.200` source, but not yet exercised live.
- GitHub Actions semantics: HIGH for the documented items (timezone, contexts, vars, types) and MEDIUM for A2, A3 and A6.
- Harness runtime and count assertions: MEDIUM. The design is sound, but the numbers must be measured on the first run.
- Pitfalls: HIGH for the gate breakage, which was read directly from the gate source.

**Research date:** 2026-09-25
**Valid until:** 2026-10-25 for the DefectDojo facts (pinned, stable). GitHub Actions moves fast, so recheck `job.workflow_*` and `timezone` status if planning slips past about 2026-10-09.
