# DefectDojo Triage Runbook

This runbook covers how to review and disposition the findings that the DefectDojo import in `.github/workflows/security.yml` loads into DefectDojo. It applies to the DefectDojo 3.3.200 install deployed by the chart in this directory. The decisions behind it are recorded in ADR-026 in the `security_solution` documentation repository. Every behaviour marked "measured" below was observed in the kind proof (`bash scripts/defectdojo-import-proof.sh`) against 3.3.200.

## System of record

- **DefectDojo is authoritative.** A finding's disposition exists only in DefectDojo. Triage decisions are made and recorded there.
- **The GitHub Security tab is per-PR developer feedback.** The SARIF uploads that fill it give a PR author quick feedback. Nobody triages there, and dismissing an alert in GitHub is not a disposition.
- **The two are not synced.** Nothing flows from GitHub to DefectDojo or from DefectDojo to GitHub. A GitHub alert dismissal does not reach DefectDojo, and a DefectDojo disposition does not close a GitHub alert.

## Before you triage

- **The bootstrap must have run.** Deduplication is off on a fresh 3.3.200 install. Run `bash scripts/defectdojo-configure.sh` once after the install, as described in the [chart README](README.md#dedup-and-triage). Without it every branch reimport piles up findings, and nothing below holds.
- **Dedup is product-wide, including container-image findings.** A repository's product holds one engagement per branch: `ci/<default>` for the default branch and `ci/<pr-branch>` for each open PR. A finding on a PR engagement that already exists on the default-branch engagement is marked as an inactive duplicate of the default-branch finding. Since `v1.3.0`, `security.yml` tags the scanned image with the fixed name `scan-target:ci`. The image name is part of each finding's content, so the same image content gives the same `trivy-image` findings on every branch and on every default-branch commit: the `trivy-image` findings on a PR engagement are duplicates of their `ci/<default>` originals, and those originals keep their ids, and their dispositions, across new default-branch commits as long as Trivy's vulnerability data for them is unchanged. Before `v1.3.0` the image was tagged with the commit SHA. That made every `trivy-image` finding on a PR engagement an active non-duplicate, and it replaced the `ci/<default>` image findings on every new default-branch commit. Findings imported before the upgrade still carry the SHA-tagged image name. The first `ci/<default>` reimport after upgrading mitigates them and creates the new set once, so False Positive, Out of Scope and Risk Accepted dispositions on the old image findings are lost that one time and must be set again on the new findings. Measured live (Phase 29, before the fix): a PR engagement holding 156 findings showed all 96 pre-existing non-image findings as duplicates and all 59 `trivy-image` findings as active non-duplicates. Measured live (Phase 29.4): the first `ci/main` reimport after the upgrade mitigated the 60 SHA-tagged `trivy-image` findings and created 60 new ones with the same 60 titles; a PR engagement imported right after it, holding 158 findings, showed all 97 pre-existing non-image findings as duplicates, the one new finding as active, and all 60 `trivy-image` findings as inactive duplicates of their `ci/main` originals with equal hash codes.
- **Dedup is within one tool.** Two tools reporting the same vulnerability produce two findings (see Expected noise).

## Triage on the default branch only

**Triage only on the default-branch engagement `ci/<default>`, for example `ci/main`. Never disposition a finding on a `ci/<pr-branch>` engagement.** This is a hard rule, not a preference.

Why:

- **PR engagements are deleted when the PR closes.** They are transient review views.
- **A PR-engagement disposition is lost on that delete.** When a finding first appears on a PR and the PR merges, the default-branch copy is a duplicate of the PR's finding. Deleting the PR engagement re-parents the default-branch copy, which becomes the original again. Measured: all 6 such copies were non-duplicate and active when read 1 s after the DELETE returned, with no reimport. But the re-parent copies only the active, verified and mitigated state. It never copies the False Positive, Out of Scope or Risk Accepted flag. A finding dispositioned on the PR engagement therefore loses that disposition, and if it had been set inactive, its default-branch copy is left inactive and un-dispositioned. A later reimport does not reactivate it, so it drops out of every queue.
- **A default-branch disposition covers future PRs.** With product-wide dedup, a PR finding that already exists on `ci/<default>` becomes a duplicate of the default-branch original, so a finding dispositioned there does not reappear as active on PR engagements. Measured: the PR copies of a False Positive, an Out of Scope and a Risk Accepted finding each arrived as an inactive duplicate of the dispositioned original, and the PR engagement had 0 active findings. From `v1.3.0` on, the same holds for `trivy-image` findings, as with every other finding: a disposition on a `ci/<default>` image finding suppresses the PR copy. Image findings imported before the upgrade lose their dispositions once (see Before you triage).

This rule also stops a PR author from hiding a finding by dispositioning it on their own PR engagement: the disposition does not outlive the PR.

## Dispositions

Every finding on `ci/<default>` is in exactly one of these states.

| State | How to set it | What reimport does |
|---|---|---|
| Under Review | Nothing to set. Every new finding lands here. It leaves the state when you set Verified or one of the dispositions below. | Stays in the queue until you act. |
| Verified/Active | Mark the finding Verified (UI) or `PATCH {"verified": true}`. It stays active and confirmed as real. | Verified is preserved. The finding stays open until it is fixed. |
| False Positive | Mark it False Positive (UI) or the FP `PATCH` below. It becomes inactive. | Measured: the finding reads `false_p=true, active=false, is_mitigated=true` from the moment it is dispositioned, and two reimports left that state and its mitigated timestamp unchanged. It is never reactivated. |
| Out of Scope | Mark it Out of Scope (UI) or the OOS `PATCH` below. It becomes inactive. | Measured: `out_of_scope=true, active=false, is_mitigated=true` from the moment it is dispositioned, unchanged by two reimports. It is never reactivated. |
| Risk Accepted | Create a full Risk Acceptance with an expiry date and a reason (see Risk acceptance). The finding becomes inactive. | Measured: `risk_accepted=true, active=false, is_mitigated=false`, unchanged by two reimports. It is never reactivated by a reimport. It is reactivated when the acceptance expires. |
| Mitigated | Nothing to set. Reimport sets it through `close_old_findings` when the scanner stops reporting the finding. | Closed while the scanner no longer reports it. If the issue comes back, the next reimport reopens it, which is intended. From v1.4.0 a reopened finding returns unverified, so it re-enters Under Review even if it was Verified before it was fixed (measured in kind, Phase 29.5). |

**Under Review is a query, not a flag.** It is the implicit untriaged queue: findings on `ci/<default>` that are active, not verified, not a duplicate, not mitigated, and carry none of False Positive, Out of Scope or Risk Accepted. In the UI, open the `ci/<default>` engagement's findings and filter on Active = Yes, Verified = No, Duplicate = No, Mitigated = No, and False Positive, Out of Scope and Risk Accepted all No. The API query is under API examples. DefectDojo also has a native "Under Review" flag; that is its multi-reviewer review-request workflow, and this runbook does not use it.

**Every parser arrives unverified from v1.4.0.** From `v1.4.0` the `security.yml` import sends `verified=false`, so findings from every parser, Trivy included, arrive unverified and the Under Review query above matches them. Verified is set only by a triager and means the finding is confirmed real. Measured in kind (Phase 29.5): every finding from all 8 reports landed `verified=false` on first import and on reimport, including a Trivy finding whose scanner status the parser maps to verified; a Verified set by a triager on an active finding was kept by the next reimport.

**Findings imported before v1.4.0 stay Verified until reset.** Before `v1.4.0` the import sent no verified field and DefectDojo's Trivy parser set `verified=true` from each vulnerability's status, so Trivy findings were absent from Under Review. A reimport does not reset Verified on a finding that is still active, so Trivy findings imported before the upgrade keep `verified=true` until the one-time reset is run (see One-time reset after upgrading to v1.4.0). Measured live (Phase 29.5): on `ci/main` the first reimport after the upgrade left 65 of 65 earlier Trivy findings `verified=true`; the one-time reset below set them to `verified=false`, after which 0 remained. That reimport brought 0 new Trivy findings, so the claim that new Trivy findings arrive unverified rests on the kind measurement.

**No reimport flag is needed.** The measured reimports reported 0 reactivated findings. Do not add `do_not_reactivate` to the reimport: it must stay off so that a fixed issue that regresses reopens.

**A dispositioned finding the scanner stops reporting is mitigated.** `close_old_findings` closes it like any other finding. For a Risk Accepted finding, that removes the acceptance, which is the correct outcome for a fixed issue.

## Risk acceptance

- **Use full risk acceptance only.** A full Risk Acceptance is an object with an owner, an expiry date and a reason, attached to one or more findings from one engagement. Products created by the import allow full risk acceptance by default. Do not enable simple risk acceptance on a product; it is a checkbox with no expiry and no reason.
- **The default expiry is 90 days.** The bootstrap sets the form's default expiry (`risk_acceptance_form_default_days`) to 90. That only pre-fills the UI form.
- **Expiry date and reason are MANDATORY by this procedure.** DefectDojo does not enforce either field; both are optional in its data model. Every Risk Acceptance must carry an expiry date and a reason (decision details) that says why the risk is accepted.
- **On expiry the finding comes back.** A Celery beat task checks for expired acceptances every 3 hours. It sets the finding back to active and not risk accepted, so it returns to the untriaged queue for a fresh decision. This is upstream behaviour read from the 3.3.200 source; it was not exercised in the proof.

The API shape, with all findings from the one `ci/<default>` engagement:

```json
{
  "name": "Accept CVE-0000-00000 until the upstream fix ships",
  "owner": 1,
  "accepted_findings": [1234],
  "expiration_date": "2026-12-31T00:00:00Z",
  "decision": "A",
  "decision_details": "No fixed release yet; not reachable from our code path."
}
```

## API examples

The token is read from a file and written to a header file with mode 0600, so it never appears on a command line or in shell history. `ENG` is the id of the `ci/<default>` engagement.

```bash
DD=https://defectdojo.example.com
HDR="$(mktemp)"; chmod 600 "$HDR"
printf 'Authorization: Token %s\n' "$(cat /path/to/token-file)" > "$HDR"
ENG=42
```

Under Review queue:

```bash
curl -sS -H @"$HDR" \
  "$DD/api/v2/findings/?test__engagement=$ENG&active=true&verified=false&false_p=false&out_of_scope=false&risk_accepted=false&duplicate=false&is_mitigated=false"
```

False Positive. The body must send `verified: false`, because 3.3.200 refuses a verified false positive:

```bash
curl -sS -X PATCH -H @"$HDR" -H 'Content-Type: application/json' \
  -d '{"false_p": true, "active": false, "verified": false}' \
  "$DD/api/v2/findings/1234/"
```

Out of Scope:

```bash
curl -sS -X PATCH -H @"$HDR" -H 'Content-Type: application/json' \
  -d '{"out_of_scope": true, "active": false}' \
  "$DD/api/v2/findings/1234/"
```

Risk Accepted. `owner` is a user id, and every id in `accepted_findings` must belong to the same engagement:

```bash
curl -sS -X POST -H @"$HDR" -H 'Content-Type: application/json' \
  -d '{"name": "Accept CVE-0000-00000 until the upstream fix ships", "owner": 1, "accepted_findings": [1234], "expiration_date": "2026-12-31T00:00:00Z", "decision": "A", "decision_details": "No fixed release yet; not reachable from our code path."}' \
  "$DD/api/v2/risk_acceptance/"
```

Remove the header file when you are done:

```bash
rm -f "$HDR"
```

## One-time reset after upgrading to v1.4.0

Findings that a Trivy parser imported before v1.4.0 arrived with `verified=true` without any triage meaning, so they are absent from Under Review, and a reimport does not reset Verified on a finding that is still active.

Scope: the `ci/<default>` engagement only; the Trivy Scan Tests titled `trivy-fs` and `trivy-image`; findings that are active, not dispositioned (not false positive, out of scope or risk accepted), not duplicate and not mitigated. PR engagements are deleted when the PR closes and need nothing.

Run this once with an operator token. It prints the candidate ids and changes nothing until you type `yes`. Keep the printed id list: setting `verified` back to `true` on those ids undoes the reset.

```bash
set -euo pipefail
DD=https://defectdojo.example.com
TOKEN_FILE=/path/to/token-file
ENG=42

case "$DD" in
  https://*) ;;
  *) echo "FAILED: DD must be https:// - refusing to send the API token" >&2; exit 1 ;;
esac

HDR="$(mktemp)"; chmod 600 "$HDR"
BODY="$(mktemp)"
trap 'rm -f "$HDR" "$BODY"' EXIT
printf 'Authorization: Token %s\n' "$(cat "$TOKEN_FILE")" > "$HDR"

# dd_api METHOD URL EXPECTED_HTTP [JSON_BODY]: response body goes to $BODY.
dd_api() {
  local out rc=0
  if [ "$#" -eq 4 ]; then
    out="$(curl -q -sS --proto =https --proto-redir =https -H @"$HDR" -X "$1" \
      -H 'Content-Type: application/json' -d "$4" \
      -o "$BODY" -w '%{http_code}|%{ssl_verify_result}' "$2" 2>/dev/null)" || rc=$?
  else
    out="$(curl -q -sS --proto =https --proto-redir =https -H @"$HDR" -X "$1" \
      -o "$BODY" -w '%{http_code}|%{ssl_verify_result}' "$2" 2>/dev/null)" || rc=$?
  fi
  if [ "$rc" -ne 0 ] || [ "${out#*|}" != 0 ] || [ "${out%%|*}" != "$3" ]; then
    echo "FAILED: $1 $2: curl exit $rc, http ${out%%|*}, TLS verification result ${out#*|} (must be 0)" >&2
    exit 1
  fi
}

# Step 1: the Trivy Scan Tests on the ci/<default> engagement.
dd_api GET "$DD/api/v2/tests/?engagement=$ENG&limit=100" 200
jq -e '.next == null' "$BODY" >/dev/null || { echo "FAILED: more than one page of Tests" >&2; exit 1; }
TESTS="$(jq -c '[.results[] | select(.engagement == '"$ENG"' and .scan_type == "Trivy Scan" and (.title == "trivy-fs" or .title == "trivy-image")) | .id]' "$BODY")"
[ "$TESTS" != "[]" ] || { echo "FAILED: no trivy-fs or trivy-image Trivy Scan Test on engagement $ENG" >&2; exit 1; }
echo "Trivy Test ids: $TESTS"

# Step 2: triage-open Trivy findings that read verified=true. Every filter is
# re-checked client-side, because a server filter that is ignored returns every row.
dd_api GET "$DD/api/v2/findings/?test__engagement=$ENG&active=true&verified=true&false_p=false&out_of_scope=false&risk_accepted=false&duplicate=false&is_mitigated=false&limit=1000" 200
jq -e '.next == null' "$BODY" >/dev/null || { echo "FAILED: more than one page of findings" >&2; exit 1; }
IDS_JSON="$(jq -c --argjson t "$TESTS" '[.results[]
  | select((.test as $x | any($t[]; . == $x))
      and .active == true and .verified == true and .false_p == false
      and .out_of_scope == false and .risk_accepted == false
      and .duplicate == false and .is_mitigated == false)
  | .id] | sort' "$BODY")"
COUNT="$(jq 'length' <<<"$IDS_JSON")"
IDS="$(jq -r '.[]' <<<"$IDS_JSON")"
printf 'Candidates (%s):\n' "$COUNT"
printf '%s\n' "$IDS"
[ "$COUNT" -gt 0 ] || { echo "Nothing to reset."; exit 0; }

# Step 3: set verified=false on each candidate, stopping on the first non-200.
read -r -p "Type yes to set verified=false on these $COUNT findings: " ANSWER
[ "$ANSWER" = yes ] || { echo "Not confirmed; nothing changed."; exit 1; }
for id in $IDS; do
  dd_api PATCH "$DD/api/v2/findings/$id/" 200 '{"verified": false}'
  echo "reset $id"
done

# Step 4: the EXIT trap removes the header file.
rm -f "$HDR"
```

## Expected noise

- **Line shifts show old issues as new on a PR.** Checkov, Gitleaks, Semgrep and SARIF (tflint) findings are matched on a hash that includes the line number. A PR that shifts lines above an existing issue shows that issue as new on the PR engagement. This is upstream behaviour, and the hash fields are deliberately not changed. Do not disposition it on the PR. The same hash means that, after such a change merges, an issue already dispositioned on `ci/<default>` can reappear there as a new finding in Under Review; disposition it again.
- **One vulnerability can appear once per SCA tool.** Trivy, npm audit and pip-audit findings for the same vulnerability do not collapse into one finding in 3.3.200, because the tools do not report a shared identifier. Measured: for the `requests` package, Trivy reported `CVE-2018-18074` while pip-audit reported `PYSEC-2018-28`, `PYSEC-2023-74`, `PYSEC-2026-1872`, `PYSEC-2026-1873` and `PYSEC-2026-2275`, with no identifier in common, and the npm audit findings carried no vulnerability identifiers at all. No duplicate link crossed scan types. Triage each tool's finding on its own.
- **Another open PR can hold the original for a while.** When a finding exists on more than one PR engagement, the default-branch copy can be re-parented onto another still-open PR's finding rather than becoming the original. It stays a duplicate until that PR closes and its engagement is deleted, when it is re-parented again. The window is bounded by the PR's lifetime; no action is needed.

## Not part of triage

- **SLA is not part of this workflow.** Days-to-fix tracking is not configured by this chart or by the bootstrap. The upstream SLA setting is left at its default, so DefectDojo may show SLA columns; ignore them.
- **Notifications, Jira and GitHub alert sync are not configured.** Triage happens in the DefectDojo UI or API, and nothing is pushed elsewhere.
