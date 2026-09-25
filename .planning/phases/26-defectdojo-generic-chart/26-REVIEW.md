---
phase: 26-defectdojo-generic-chart
reviewed: 2026-09-24T23:30:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - repos/security-platform/kubernetes/defectdojo/Chart.yaml
  - repos/security-platform/kubernetes/defectdojo/Chart.lock
  - repos/security-platform/kubernetes/defectdojo/.helmignore
  - repos/security-platform/kubernetes/defectdojo/values.yaml
  - repos/security-platform/kubernetes/defectdojo/templates/validate-tls.yaml
  - repos/security-platform/kubernetes/defectdojo/README.md
  - repos/security-platform/scripts/check-defectdojo-chart.sh
  - repos/security-platform/scripts/defectdojo-live-smoke.sh
  - repos/security-platform/README.md
  - docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md
  - docs/adr/README.md
findings:
  critical: 0
  warning: 5
  info: 8
  total: 13
status: issues_found
---

# Phase 26: Code Review Report

**Reviewed:** 2026-09-24T23:30:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

I reviewed the DefectDojo wrapper chart, its TLS guard, the offline gate, the live smoke, the two READMEs and ADR-023 against `security-platform` `main` at `71a112e`. I ran the offline gate with Helm v4.3.0 and yq v4.53.6, and it printed `PASS - 20 checks, 0 failures`. I also ran offline `helm template --namespace defectdojo` probes against the TLS guard. I did not run the live smoke or any command against a cluster.

I found no Critical issues. The main problems:

- **The TLS guard checks a different annotation set than the one the Ingress actually gets.** Upstream merges `extraAnnotations` into the Ingress annotations, and the guard ignores them. My probes produced both a false rejection and a false acceptance (WR-01).
- **The chart README's Secret-naming rule is wrong for release names that merely contain `defectdojo`.** A consumer who follows it creates a Secret the pods never read (WR-02).
- **The README's Secret recipe can leak the admin password.** In zsh, macOS's default shell, `read -rsp` fails and leaves the password empty. The recipe still applies `DD_ADMIN_PASSWORD: ""`, which is the case in which the initializer prints a generated password to the pod log (WR-03).
- **The offline gate's preflight hint still gives the build-only command that PR #20 fixed everywhere else** (WR-04).
- **The gate's plan-era SKIP guard now lets a deleted TLS guard pass as exit 0** (WR-05).

`security-platform` files are already public, so fixes to them need a follow-up PR. The ADR-023 and ADR index findings can be fixed in this repository, but ADR-023 is accepted and the ADR directory is append-only. Operator decisions a-g are not re-litigated here. WR-01 concerns the guard's implementation, not the accepted fail-guard mechanism.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: TLS guard reads only `django.ingress.annotations`, but upstream also merges `extraAnnotations` into the Ingress

**File:** `repos/security-platform/kubernetes/defectdojo/templates/validate-tls.yaml:35-43`
**Issue:** The upstream `defectdojo/templates/django-ingress.yaml` (1.9.53) writes `.Values.extraAnnotations` and then `.Values.django.ingress.annotations` into the same Ingress `metadata.annotations` map. The guard inspects only `$ing.annotations`, so what it validates is not what cert-manager's ingress-shim sees. Measured offline:
- False rejection: `--set 'defectdojo.extraAnnotations.cert-manager\.io/cluster-issuer=x'` fails with "no cert-manager issuer is set", although the rendered Ingress would carry the issuer.
- False acceptance: `--set 'defectdojo.extraAnnotations.cert-manager\.io/cluster-issuer=x' --set 'defectdojo.django.ingress.annotations.cert-manager\.io/issuer=y'` renders successfully. The Ingress carries both `cert-manager.io/cluster-issuer: "x"` and `cert-manager.io/issuer: "y"`, which is exactly the ambiguous case the "set only one of" branch exists to refuse. cert-manager then issues no Certificate.
**Fix:** Build the map the Ingress actually gets, with the same precedence as upstream (ingress annotations win). Keep the three asserted message substrings unchanged, because gate checks 2, 4 and 5 match on them:
```yaml
{{- $ing := .Values.defectdojo.django.ingress -}}
{{- if and $ing.enabled $ing.activateTLS -}}
{{-   $a := mergeOverwrite (dict) (.Values.defectdojo.extraAnnotations | default dict) ($ing.annotations | default dict) -}}
...
```
Add a gate check for the extraAnnotations both-keys case so the fix cannot regress.

### WR-02: README gets the application Secret name wrong for any release name that contains `defectdojo` but is not exactly `defectdojo`

**File:** `repos/security-platform/kubernetes/defectdojo/README.md:66`
**Issue:** The table says the app Secret is "literally `defectdojo` when the release name contains `defectdojo`, otherwise `<release>-defectdojo`". The subchart's `defectdojo.fullname` helper returns the release name itself whenever it contains `defectdojo` (`if contains $name .Release.Name` → `.Release.Name`). I rendered with release `my-defectdojo` and got Deployments `my-defectdojo-django` etc., so the Secret they read is `my-defectdojo`, not `defectdojo`. A consumer with a release named `defectdojo-prod` or `my-defectdojo` who follows the README creates `defectdojo`. The django pod then stops at `CreateContainerConfigError` on `METRICS_HTTP_AUTH_PASSWORD`. The README also omits `fullnameOverride`, which renames the Secret too.
**Fix:**
```markdown
| The subchart fullname: the release name itself when it contains `defectdojo` (release `defectdojo` → `defectdojo`, release `defectdojo-prod` → `defectdojo-prod`), otherwise `<release>-defectdojo`; `defectdojo.fullnameOverride` replaces it | ...
```

### WR-03: README Secret recipe fails in zsh and then applies an empty `DD_ADMIN_PASSWORD`, the T-26-03 leak it warns about

**File:** `repos/security-platform/kubernetes/defectdojo/README.md:85-117`
**Issue:** `read -rsp 'DefectDojo admin password: ' DD_ADMIN_PW` is bash syntax. In zsh, the macOS default interactive shell, `-p` means "read from coprocess". Verified locally: `zsh:read:1: -p: no coprocess`, rc=1, variable empty. The block is an interactive paste sequence with no `set -e`, so the heredoc still runs and applies `DD_ADMIN_PASSWORD: ""`. The same happens in bash if the operator just presses Enter. The README's own line 72 says a missing admin password makes the initializer generate one and print it to the pod log. Upstream checks the variable with a falsy test (`if not os.getenv("DD_ADMIN_PASSWORD")`), so an empty string counts as missing (inferred from the upstream source, not measured live). Nothing in the recipe refuses an empty password.
**Fix:** Use a portable prompt and refuse an empty value before anything is applied:
```bash
printf 'DefectDojo admin password: ' >&2; IFS= read -rs DD_ADMIN_PW; echo
[ -n "$DD_ADMIN_PW" ] || { echo 'empty admin password refused' >&2; return 1 2>/dev/null || exit 1; }
```
Alternatively, state explicitly that the block must be pasted into bash.

### WR-04: Offline gate's preflight remediation still prints the build-only command that PR #20 fixed elsewhere

**File:** `repos/security-platform/scripts/check-defectdojo-chart.sh:90-93`
**Issue:** On a fresh clone the gate exits 2 and tells the operator `run: helm dependency build kubernetes/defectdojo`. ADR-023 decision 11 records that this exact command fails on a clean machine with "no repository definition for https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts. Please add the missing repos via 'helm repo add'". PR #20 fixed the README and the live smoke but not this hint. The same stale wording is in the comment at lines 74-77. The first thing a new contributor sees from the gate is a command that does not work.
**Fix:**
```bash
  echo "PREFLIGHT FAIL: subchart not vendored — ${DEP_TGZ} does not exist"
  echo "run: helm repo add defectdojo $(yq '.dependencies[0].repository' "${CHART_DIR}/Chart.yaml") && helm dependency build ${CHART_DIR}"
```
The alternative is to point at the README's Install section. ADR-023 "What was NOT verified" item 8 already notes that `check-nexus-chart.sh` and the Nexus README probably have the same gap.

### WR-05: Plan-era SKIP guard lets the gate exit 0 when the TLS guard, the chart's security control, is deleted

**File:** `repos/security-platform/scripts/check-defectdojo-chart.sh:59-63` (also 53-57)
**Issue:** Guard 2 prints `SKIP:` and exits 0 whenever `templates/validate-tls.yaml` is missing. That was right while the phase was being built (26-01 to 26-02). The chart is now complete and public, so deleting or renaming the guard template no longer turns the gate red. It turns it green-with-SKIP. Check 2's failure text ("or the TLS guard is gone") can never be reached for that cause, because Guard 2 short-circuits first. The comment's "anti-vacuity guard ... asserts the literal terminal PASS line" is a human or plan check. Neither `.github/workflows/pr-security.yml` nor `security.yml` runs this gate, so nothing automated asserts the PASS line. Guard 1 has the same effect if the whole chart directory is removed or renamed.
**Fix:** Now that the chart exists, make a missing guard a failure. For example, keep Guard 1 (chart absent → SKIP) only if still wanted, and replace Guard 2 with:
```bash
if [ ! -f "${CHART_DIR}/templates/validate-tls.yaml" ]; then
  echo "FAIL: TLS-GUARD-PRESENT: ${CHART_DIR}/templates/validate-tls.yaml is missing — the issuer guard is gone"
  exit 1
fi
```
Update the SKIP-convention comment (lines 35-45) to match, and consider wiring the gate into CI.

## Info

### IN-01: Guard's not-both check uses truthiness, cert-manager uses key presence

**File:** `repos/security-platform/kubernetes/defectdojo/templates/validate-tls.yaml:36-43`
**Issue:** `get` returns `""` for both an absent key and an empty value. Measured: `cluster-issuer=""` plus `issuer=x` renders successfully and puts both keys on the Ingress (`cert-manager.io/cluster-issuer: ""`, `cert-manager.io/issuer: "x"`). As I recall ingress-shim's source, it decides by key presence and refuses an Ingress carrying both annotation keys. I did not verify that against v1.21. The input is contrived, but a layered overlay that "clears" a base issuer with `""` produces exactly this.
**Fix:** Use `hasKey $a "cert-manager.io/cluster-issuer"` and `hasKey $a "cert-manager.io/issuer"` for the both-keys branch. Separately, fail on a present-but-empty value.

### IN-02: Guard does not reject an empty `host` with TLS on

**File:** `repos/security-platform/kubernetes/defectdojo/templates/validate-tls.yaml:44-46`
**Issue:** `--set defectdojo.host=` renders `tls: [{hosts: [null]}]` and `rules: [{host: null}]` (measured). ingress-shim then has no dnsName to put on the Certificate. The guard's stated purpose is to abort when the TLS path is misconfigured, and this is the one TLS input it does not check.
**Fix:** `{{- if not .Values.defectdojo.host -}}{{- fail "defectdojo.host must be non-empty when TLS is on" -}}{{- end -}}` inside the TLS branch.

### IN-03: `jq` is a hard preflight in the offline gate but is never used

**File:** `repos/security-platform/scripts/check-defectdojo-chart.sh:66`
**Issue:** `for bin in helm yq jq` exits 2 ("machine problem") when jq is absent, but the only occurrence of `jq` in the script is that line. A machine with only helm and yq is refused for no reason.
**Fix:** `for bin in helm yq tar grep; do` (tar is used by IMAGE-PIN).

### IN-04: Offline gate does not verify the yq flavor, so a wrong yq is reported as a chart defect (exit 1) rather than preflight (exit 2)

**File:** `repos/security-platform/scripts/check-defectdojo-chart.sh:66-71, 210, 224, 310`
**Issue:** The checks rely on mikefarah yq v4 syntax (`yq ea`, `tag == "!!map"`). With the Python `yq` (a jq wrapper, which is also packaged as `yq`), the preflight passes. Every `yq ea` call then fails and is reported as `FAIL:` with exit 1. That breaks the header's promise that infrastructure and chart defects "must never be conflated".
**Fix:** Add a preflight check: `yq --version 2>&1 | grep -q 'mikefarah' || { echo "PREFLIGHT FAIL: mikefarah yq v4 required"; exit 2; }`.

### IN-05: README says the smoke "never touches your current kube context", but it rewrites it for the whole run

**File:** `repos/security-platform/kubernetes/defectdojo/README.md:309`; `repos/security-platform/scripts/defectdojo-live-smoke.sh:106-111, 338`
**Issue:** `kind create cluster` switches the operator's current-context to `kind-dd-smoke` for the 10-20 minute run. The script's own comment says so, and the EXIT trap restores the context. Any `kubectl` in another terminal during the run hits kind, and a SIGKILL leaves the context switched. The README claim is inaccurate.
**Fix:** Reword to "switches the current context to the kind cluster while it runs and restores the previous context on exit". Better, isolate it: `export KUBECONFIG="$OUT/kubeconfig"` before `kind create cluster`, so the operator's kubeconfig is never written.

### IN-06: Live smoke has unguarded commands under `set -e` that abort without the summary

**File:** `repos/security-platform/scripts/defectdojo-live-smoke.sh:461, 469-497, 596`
**Issue:** `kubectl create namespace`, the Secret `kubectl apply` and `base64 -d` are not wrapped. A failure aborts via `set -e` with the kubectl or base64 exit code and no named FAIL or `=== Summary ===`. That contradicts the script's convention that every exit path prints the summary. The exit is still non-zero and the trap still cleans up.
**Fix:** Wrap each command: `if ! kubectl ... create namespace "$KIND_NS" >/dev/null; then fail "KIND-SECRETS" "..."; print_summary; fi`, and the same for the apply and the decode.

### IN-07: Hardcoded Referer duplicates `BASE_URL`

**File:** `repos/security-platform/scripts/defectdojo-live-smoke.sh:682`
**Issue:** `-H "Referer: https://defectdojo.smoke.test:18443/login"` repeats `SMOKE_HOST` and `PF_PORT` as a literal. If either constant changes, the Referer no longer matches the origin and the login POST gets a CSRF 403. The script tells readers to treat that 403 as an operator finding, not a smoke defect.
**Fix:** `-H "Referer: ${BASE_URL}/login"`.

### IN-08: Subchart version literal repeated outside the four documented pin points

**File:** `repos/security-platform/kubernetes/defectdojo/values.yaml:4, 9`; `repos/security-platform/kubernetes/defectdojo/README.md:5, 13, 20, 236, 313`
**Issue:** `1.9.53` (including the `tar -xOzf charts/defectdojo-1.9.53.tgz` command) appears in comments and docs that the README's manual bump procedure (README:343-346) does not mention, and that IMAGE-PIN does not check. After a bump these commands point at a tarball that no longer exists.
**Fix:** Add "update the version literals in the values.yaml header and README" to the bump procedure, or write the commands version-agnostically (`tar -xOzf charts/defectdojo-*.tgz defectdojo/values.yaml`).

---

_Reviewed: 2026-09-24T23:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
