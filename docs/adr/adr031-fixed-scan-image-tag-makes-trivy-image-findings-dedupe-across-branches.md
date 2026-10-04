# ADR-031: A Fixed Scan Image Tag Makes trivy-image Findings Dedupe Across Branches and Main Commits

**Status:** Accepted
**Date:** 2026-10-04
**Addresses:** Phase 29 follow-up (b) (`deferred-items.md`, a fixed scan-image tag), Phase 29 WR-04 (29-REVIEW, the
`ci/main` trivy-image findings were replaced on every new `main` SHA), DDOJO-03 for the `trivy-image` Test, and the
ADR-027 tradeoff "trivy-image findings do not dedupe across branches"

This record lives in this documentation repository. The IMAGE-TAG check header in
`scripts/check-workflow-uploads.sh` and the container-job comment in `.github/workflows/security.yml` in the public
`security-platform` repository cite it by number, so a reader of the public repository cannot follow the link. That
is the arrangement ADR-022 to ADR-030 recorded. Every measured value below is quoted from a Phase 29.4 plan summary
(29.4-01 to 29.4-09) or from a file in that phase's `evidence/` directory, and each is attributed where it appears.
This record was written after `v1.3.0` was tagged (29.4 D-18), so the WR-04 measurement and the tag readback are
quoted from evidence rather than predicted.

## Context

- **The gap was measured live in Phase 29.** In 29-16 (PR #25, engagement 2) the PR engagement held 156 findings.
  All 96 pre-existing non-image findings were inactive duplicates of their `ci/main` originals, and all 59
  trivy-image findings (Test `trivy-image`, scan_type `Trivy Scan`) were active non-duplicates, with `file_path`
  `scan-target:17fd99dc… (debian 12.15)` on the PR against `scan-target:2fda1ac… (debian 12.15)` on `ci/main`
  (ADR-027 tradeoff; Phase 29 `deferred-items.md`). `security.yml` built and scanned `scan-target:${{ github.sha }}`,
  and a PR's merge SHA never equals the default branch's. ADR-027 recorded the gap as a tradeoff, and the D-11 step 2
  assertion was amended to exclude the trivy-image Test (`D11-STEP2-EXCLUSION-KEY`, `security-platform` `v1.2.0`).
- **The root cause is `description`, not `file_path`.** ADR-027 said the tag "appears in each finding's
  `file_path`", and that is true, but `file_path` is a stored field, not a hashed one. In DefectDojo 3.3.200 the
  `Trivy Scan` hash fields are `title`, `severity`, `vulnerability_ids`, `cwe` and `description` (plus `service`,
  which is always hashed). The parser builds `description` from a template that contains a `**Target:** {target}`
  line, where `target` is `Results[].Target`, for example `scan-target:<sha> (debian 12.15)`. That line is how the
  image reference reaches `hash_code`. `file_path` carries the same string only because os-pkgs vulnerabilities have
  no `PkgPath` (29.4-RESEARCH, Finding 1). ADR-027 follow-up (b) left this open ("`file_path`, measured to hold it,
  or also `description`"). The fixed tag makes both fields constant, so the correction does not change the fix.
- **WR-04 was inferred, not measured.** The same hash made every new `main` SHA a new image target on `ci/main`.
  Each reimport with `close_old_findings` mitigated the previous set of trivy-image findings and created a new one,
  so ids and any dispositions on them did not survive a `main` commit (29-REVIEW WR-04). The 29.4-05 before-upgrade
  snapshot showed the residue: image Test 4 held 120 findings, 60 live on `scan-target:30afdb9…`, 59 mitigated on
  `scan-target:2fda1ac…` and 1 mitigated on `scan-target:30afdb9…` (29.4-05-SUMMARY).
- **ADR-026, ADR-027 and ADR-029 may not be edited.** `docs/adr/` is append-only per `CLAUDE.md`. The supersession
  below is stated in this record's prose.

## Decision

1. **The container job builds and scans the fixed literal `scan-target:ci` (D-01).** Both `docker build ... -t` and
   `trivy image` in the `container` job of `security.yml` use `scan-target:ci`, and the interpolation comment no
   longer lists `${{ github.sha }}`. `github.sha` no longer appears in `security.yml` (count 0). Identical image
   content now yields identical Trivy findings, and identical `hash_code` values, on every branch and every `main`
   SHA. Implemented in `security-platform` commit `3c547c6` (29.4-01), merged through PR #32.
   - **Why a fixed tag is collision-free, and its standing dependency.** The container job runs on GitHub-hosted
     `ubuntu-latest`; unlike the DefectDojo jobs it is not routed through `vars.DEFECTDOJO_RUNS_ON`. Each run gets a
     fresh Docker daemon, so no earlier `scan-target:ci` image can be scanned by mistake. The fix depends on that.
     If the container job ever becomes runner-overridable or runs on a persistent daemon, the fixed tag can collide
     and this decision must be revisited (29.4-RESEARCH, threat "fixed tag collision on a persistent daemon").
   - **Rejected alternatives.** A repository-qualified image name, and `docker save` followed by
     `trivy image --input`, were both rejected as larger changes with no benefit on a fresh daemon (D-01). Overriding
     the `Trivy Scan` hash fields in DefectDojo, for example to drop `description`, is foreclosed by ADR-026 (D-07,
     no hash-field override), and would also weaken dedup for real content changes.
2. **A static gate holds the tag (D-04).** `scripts/check-workflow-uploads.sh` gained IMAGE-TAG (check 21). It
   finds the steps `Build image from discovered Dockerfile` and `Run Trivy image scan` by name, requires
   `-t scan-target:ci` and `trivy image scan-target:ci` exactly once each, and fails if any `run:` in the `container`
   job contains `github.sha`. Against the unfixed workflow it failed RED with 4 `FAIL: IMAGE-TAG:` lines, and each of
   three scratch regressions (build line reverted, scan line reverted, an added retag step) exited 1. GREEN is
   `PASS - 21 checks, 0 failures` (29.4-01, `evidence/29.4-01-image-tag-gate.txt`; commit `49517e9`).
3. **A kind proof, P-IMAGE-TAG, proves the hash claim (D-06).** `scripts/defectdojo-import-proof.sh` takes one real
   `trivy-image.json` and writes copies that differ only in the image target. A negative control (two different SHA
   tags) must reproduce the 29-16 gap, and a positive case (both `scan-target:ci`) must produce only inactive
   duplicates of the `ci/main` findings. `file_path` was added to the proof's `FIELDS` (29.4-03).
4. **The live assertion replaces the exclusion (D-08, D-09, D-21).** In `scripts/defectdojo-lifecycle-assert.sh`,
   `assert-pr-duplicates` no longer excludes the trivy-image Test. `D11-STEP2-EXCLUSION-KEY` is replaced by
   `D11-STEP2-TRIVY-IMAGE-KEY` and `D11-STEP2-TRIVY-IMAGE-DEDUP` (`security-platform` commit `3c4ba15`, 29.4-02): every PR trivy-image finding with a `ci/main` title counterpart must be
   a duplicate pointing at that counterpart; a counterpart with a different `hash_code` is a FAIL that prints both
   hashes; only a finding with no title counterpart counts as Trivy DB drift.
5. **Consumer text follows the evidence (D-10, D-15, D-19).** `security-platform` PR #34 (PR B) rewrote the
   `kubernetes/defectdojo/TRIAGE.md` caveat "Dedup is product-wide, except for container-image findings" and its
   README twin to say that `trivy-image` findings dedupe across branches from `v1.3.0` on, with the one-time
   replacement on upgrade. `docs/adoption-guide.md` §12 in this repository carries the upgrade line (29.4-07).
6. **Release: `v1.3.0`, with `v1` moved (D-12).** The change is visible to consumers in scan output and as one-time
   DefectDojo churn, so it is a minor release, following the `v1.2.0` precedent. `v1.3.0` is an annotated tag on
   the PR B merge `aa48081`, and the lightweight `v1` moved there from `fdabac9` (ADR-018). `v1.3.0` also carries
   the Phase 29.2 TLS hardening that had been merged but not released (ADR-029): `"curl", "-q"` occurs 0 times in
   `security.yml` at `v1.2.0` and 2 times at `aa48081` (29.4-09, `evidence/29.4-09-impact-check.json` d14_4). No
   GitHub Release object was created (`evidence/29.4-09-tags.json`, `github_release_created: false`).

**Supersession.** This record supersedes, in prose, the ADR-027 tradeoff "trivy-image findings do not dedupe across
branches" from `v1.3.0` on, and it closes ADR-027 "What was NOT verified" item 4 follow-up (b) (a fixed scan-image
tag). It also answers that item's open question: the SHA reached the dedup key through `description`. ADR-027's
statement remains an accurate record of `v1.2.0` and earlier. This record changes nothing in ADR-026 (product-wide
dedup and triage on the default branch now hold for the `trivy-image` Test too, which is what ADR-026 intended) or
in ADR-029.

## Measured evidence

| Measurement | Result | Source |
|---|---|---|
| IMAGE-TAG gate | RED 4 `FAIL: IMAGE-TAG:` lines; 3 of 3 scratch negatives exit 1; GREEN `PASS - 21 checks, 0 failures` | 29.4-01, `evidence/29.4-01-image-tag-gate.txt` |
| Kind proof on PR A (#32, head `91501ca`) | DefectDojo Import Proof run 37157681058: `PROOF PASS - 172 assertions`, 6 `PROOF: P-IMAGE-TAG PASS` lines, 0 FAIL lines | 29.4-04, `evidence/29.4-04-pr-a-run.txt` |
| P-IMAGE-TAG negative control (two SHA tags) | 60 of 60 PR trivy-image findings active non-duplicates (29-16 reproduced) | `evidence/29.4-04-pr-a-run.txt` |
| P-IMAGE-TAG positive case (both `scan-target:ci`) | 60 of 60 PR trivy-image findings inactive duplicates of a `ci/main` finding; no SHA-bearing hashed field survives (D-03) | `evidence/29.4-04-pr-a-run.txt` |
| D-01 live scan output | PR Security run 37157681084: `ArtifactName` `scan-target:ci`; 1 Result with 60 vulnerabilities; no 40-hex SHA after `scan-target:` | 29.4-04-SUMMARY |
| Kind proof on PR B (#34, head `bc0eb52`) | run 37228558918: `PROOF PASS - 172 assertions`, 6 P-IMAGE-TAG PASS, 0 FAIL | 29.4-07-SUMMARY, `evidence/29.4-07-pr-b.txt` |
| PR A merge | #32 merged untagged as `2dccff51de278c29a18f2349da7d7f3f5a568579` at 2026-10-04T18:52:27Z; merge tree identical to `91501ca` | 29.4-05, `evidence/29.4-05-merge.txt` |
| D-14.1 upgrade churn | dispatch 37226275966 on `2dccff5`; image Test 4 before: total 120, active 60, mitigated 60, duplicate 0; after: total 180, active 60, mitigated 120, duplicate 0; old 60 mitigated, new 60 active on `scan-target:ci (debian 12.15)`; titles common 60, old-only 0, new-only 0; verdict PASS | `evidence/29.4-05-d14-1-upgrade.json` |
| D-08 PR dedup live (throwaway PR #33, engagement 8) | 5 of 5 D11-STEP2 checks PASS; PR Test 59 against `ci/main` Test 4; `TRIVY-IMAGE-DEDUP` matched 60 of 60, drift 0, bad 0, `hash_compared` true; 97 duplicates point to `ci/main`; the only untriaged finding is the fixture | 29.4-06, `evidence/29.4-06-step2/step2-assert.json` |
| PR B merge | #34 merged as `aa48081681ee1e578c50d6a0d9e5ead6ff6afc67` at 2026-10-04T19:59:33Z; merge tree identical to `bc0eb52` | 29.4-08, `evidence/29.4-08-merge.txt` |
| D-11 / WR-04 persistence across `main` SHAs | dispatch 37230464825 on `aa48081`; `--mode persist` PASS: A 60, B 60, persisted 60, removed 0, added 0, recreated 0, drift `[]`; image Test id 4 on both sides; reimport 145 shows 60 findings, all action U (untouched) | `evidence/29.4-08-d11-persist.json`, 29.4-08-SUMMARY |
| D-14.2 code scanning | before (run 36846632465) and after (run 37226275966): `partialFingerprints` 0, `artifactLocation.uri` `library/scan-target`, the tag only inside `runs[0].properties`; the image id is identical on both sides | `evidence/29.4-09-impact-check.json` d14_2 |
| D-14.3 workflow surface | `v1.2.0` to `aa48081`: structure identical except `run:` bodies of the two container steps, `dd-import` and `dd-delete`; 3 of 3 negatives exit 1; `check-workflow-uploads.sh` at `aa48081` `PASS - 21 checks, 0 failures` | `evidence/29.4-09-impact-check.json` d14_3 |
| D-14.4 Phase 29.2 content | `"curl", "-q"` 0 at `v1.2.0`, 2 at `aa48081`; `ssl_verify_result` 4; `v1^{}` and `v1.3.0^{}` equal `aa48081` after the tag | `evidence/29.4-09-impact-check.json` d14_4, `evidence/29.4-09-tags.json` |
| D-14.5 `@v1` callers | 61 org repositories scanned, 0 `uses:` callers found; operator confirmed verbatim `approve - no @v1 callers outside the org` | `evidence/29.4-09-impact-check.json` d14_5, `evidence/29.4-09-tags.json` |
| D-14.6 no-Dockerfile consumers | 8 of 8 container steps after `Detect Dockerfile` carry the `found == 'true'` guard; `dd-import` skips a missing `trivy-image.json` | `evidence/29.4-09-impact-check.json` d14_6 |
| D-22 release hazard | Dependabot #30 and #31 (touch `security.yml`, base `30afdb9`) held unmerged until after the tag | `evidence/29.4-09-impact-check.json` d22 |
| Release | `v1.3.0` annotated tag object `21c50379710bd945c55d4f8a18cc205bb6b6bfca` dereferences to `aa48081681ee1e578c50d6a0d9e5ead6ff6afc67`, tagger date 2026-10-04T20:15:22Z; tag message byte-identical to `evidence/29.4-09-tag-message.txt` (2263 bytes); `v1` moved from `fdabac9464f2baaeaa276f8934dc8d353295b355` to `aa48081`; `v1.2.0` (`b8ae59d` to `fdabac9`) and `v1.1.1` unchanged | `evidence/29.4-09-tags.json` |

Rollback, not run: `git tag -f v1 fdabac9464f2baaeaa276f8934dc8d353295b355` and a forced push of `refs/tags/v1` in
`security-platform`; `v1.2.0` and `v1.1.1` remain immutable escape hatches (`evidence/29.4-09-tags.json`).

## Consequences

**Improved:** a PR engagement's active list is now what the PR introduces, for container-image findings as well.
The `TRIAGE.md` and adoption-guide claim "A PR shows only what it introduces" holds for the `trivy-image` Test.

**Improved (WR-04):** `ci/main` trivy-image finding ids persist across `main` commits, so dispositions recorded on
the default branch (ADR-026) survive the next `main` SHA and apply to PR copies.

**Upgrade note (D-15, the third of three places; the others are the `v1.3.0` release notes and
`docs/adoption-guide.md` §12):** the first `ci/<default>` reimport after a consumer moves to `v1.3.0` mitigates the
SHA-tagged trivy-image findings and creates a new `scan-target:ci` set, once. Measured on the homelab: 60 old
findings mitigated, 60 new created, 0 duplicates (`evidence/29.4-05-d14-1-upgrade.json`). False-positive,
risk-accepted or out-of-scope dispositions recorded on the old image findings are lost once. That follows from
`close_old_findings` and a changed `hash_code`; it was not measured, because the homelab `ci/main` had no
dispositions on its image findings. Consumers whose repositories have no Dockerfile see no change (d14_6).

**Tradeoff — persistence holds only while the Trivy DB content is unchanged.** `description` embeds Trivy's title,
description text and fixed version, and `severity` is hashed too. A Trivy DB update that changes any of these for a
vulnerability changes its `hash_code`: the `ci/main` reimport closes and re-creates that finding, and a PR copy
scanned after the change is not a duplicate. The D-21 diagnostic reports that case with both hashes. 29.4-RESEARCH
measured 0 such changes over 8 hours. D-14.2 observed one real instance: CVE-2026-103111 `libpcre2-8-0` had an empty
fixed version on 2026-10-01 and `10.42-1+deb12u2` on 2026-10-04 (`evidence/29.4-09-impact-check.json` d14_2). That
change fell across the upgrade, where every finding was replaced anyway, so its effect on its own was not measured.

**Tradeoff — the fix depends on a fresh daemon.** See decision 1. The JOB-SHAPE check keeps the scan jobs on
`ubuntu-latest` (29.4-RESEARCH).

**Unchanged:** Mode A consumers (copied workflows) change only when they re-copy `security.yml`. GitHub code-scanning
alerts for `trivy-image` are unaffected: the SARIF location URI is `library/scan-target`, without the tag (d14_2).

## What was NOT verified

What WAS measured and must not be re-litigated: the IMAGE-TAG RED and GREEN runs (29.4-01), the P-IMAGE-TAG kind
proof with its negative control (29.4-04, 29.4-07), the live D-14.1 upgrade churn (29.4-05), the live D-08 PR dedup
(29.4-06), the live D-11 persistence across two `main` SHAs (29.4-08), and the tag readback (29.4-09).

1. **Callers outside visible repositories (29.4-RESEARCH A3).** The impact check enumerated only
   OttawaCloudConsulting default branches visible to the token. The operator confirmed there are no `@v1` callers
   outside the org; that is an operator statement, not an enumeration.
2. **A persistent Docker daemon.** The container job has run only on GitHub-hosted `ubuntu-latest`. Behaviour on a
   persistent daemon, where a stale `scan-target:ci` could be scanned, was not tested and is the reason for the
   standing dependency in decision 1.
3. **The D-21 different-hash path live.** No live PR copy had a title counterpart with a different `hash_code`;
   the FAIL path (`hash_code_differs`, both hashes printed) is proven offline only (29.4-02 replay case R4).
4. **lang-pkgs findings.** The measured image has one Result of class os-pkgs (60 of 60 findings). A lang-pkgs
   finding carries `PkgPath` in `file_path` rather than the image reference; its `description` still carries the
   constant `**Target:**` line, but no lang-pkgs finding was imported.
5. **Lost dispositions on upgrade.** Inferred from `close_old_findings` semantics (see Consequences), not measured.
6. **A cron-fired post-upgrade import.** Both post-merge `ci/main` imports were operator-approved
   `workflow_dispatch` runs of Scheduled Security (D-17). A scheduled run uses the same workflow and job, but none
   was observed against `scan-target:ci` in this phase.
7. **Mode A copies.** No consumer repository that copies `security.yml` was re-copied or measured.
