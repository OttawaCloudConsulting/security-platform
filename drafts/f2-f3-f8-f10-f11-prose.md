# Draft: Features 2, 3, 8, 10, 11 — Prose Changes, Config Fixes, Text Replacements

**Agent:** Draft Agent C
**Date:** 2026-02-24
**Source document:** `development-security-stack-option-1.md`
**Features covered:** 2 (Branch Protection), 3 (DefectDojo Hardening), 8 (Nexus Honesty), 10 (Token Security), 11 (Alert Fatigue)

---

## FEATURE 2 — Branch Protection Promoted to Required

### CHANGE 2.1 — Remove "(Optional)" from Phase 2 deliverables and add required step with instructions

FIND (exact text to locate in the document):
```
- (Optional) Branch protection rule configured to require the workflow to pass before merge
```

REPLACE WITH:
```
- Branch protection configured on the `main` branch (required — without this, the CI security gate is advisory-only and provides zero enforcement)

  **Configure in GitHub:** Settings → Branches → Branch protection rules → Add rule
  - Branch name pattern: `main`
  - Enable: **Require a pull request before merging**
  - Enable: **Require status checks to pass before merging** — add each security workflow job as a required check: `sast`, `iac`, `sca`, `container`, `secrets`
  - Enable: **Do not allow bypassing the above settings**
  - Enable: **Restrict who can push to matching branches** (block direct pushes to `main`)

  Without branch protection, a developer can push directly to `main` (bypassing all PR-based scanning), and failing scanner jobs have no effect on merge eligibility. The `continue-on-error` changes described above only enforce quality gates when branch protection makes those status checks required.
```

---

### CHANGE 2.2 — Add branch protection validation step to Phase 2 validation

FIND (exact text to locate in the document):
```
**Validation:** Open a Pull Request that contains a deliberate IaC misconfiguration (e.g., an S3 bucket with public access enabled in Terraform). Checkov should flag it in the PR checks. Confirm results appear in the Security tab.

---

### Phase 3 — Self-Hosted Infrastructure (Nexus + DefectDojo)
```

REPLACE WITH:
```
**Validation:** Open a Pull Request that contains a deliberate IaC misconfiguration (e.g., an S3 bucket with public access enabled in Terraform). Checkov should flag it in the PR checks. Confirm results appear in the Security tab.

Validate branch protection is active: attempt `git push origin main` directly from a local branch without opening a PR. GitHub should reject the push with a branch protection error. Confirm that a PR with a failing required status check cannot be merged (the merge button should be disabled or show a blocking status).

---

### Phase 3 — Self-Hosted Infrastructure (Nexus + DefectDojo)
```

---

## FEATURE 3 — DefectDojo Deployment Hardening

### CHANGE 3.1 — Pin DefectDojo tag in the Tool Details section (Section 8)

FIND (exact text to locate in the document):
```
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  --set django.ingress.enabled=true \
  --set host="defectdojo.local" \
  --set tag="latest"

kubectl get secret defectdojo -n defectdojo \
  -o jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 -d

kubectl port-forward -n defectdojo svc/defectdojo-django 8080:80
```

REPLACE WITH:
```
# Replace 2.x.y with the current stable release from:
# https://github.com/DefectDojo/django-DefectDojo/releases
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  --set django.ingress.enabled=true \
  --set host="defectdojo.local" \
  --set tag="2.x.y"

kubectl get secret defectdojo -n defectdojo \
  -o jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 -d

kubectl port-forward -n defectdojo svc/defectdojo-django 8080:80
```

---

### CHANGE 3.2 — Add "Storing Helm Values" subsection after the DefectDojo Helm install block (Tool Details section)

FIND (exact text to locate in the document):
```
**Or Docker Compose:**

```bash
git clone https://github.com/DefectDojo/django-DefectDojo
cd django-DefectDojo
./docker/docker-compose-check.sh
docker compose up -d
docker compose logs initializer | grep "Admin password"
```
```

REPLACE WITH:
```
#### Storing Helm Values

Store the install configuration in a version-controlled file instead of passing `--set` flags inline. This makes the deployment reproducible and is required before you can run `helm upgrade` reliably.

```yaml
# defectdojo-values.yaml — commit this to your infrastructure repository
django:
  ingress:
    enabled: true
host: "defectdojo.local"
tag: "2.x.y"  # Update this value when upgrading; check release notes first
```

Install or reinstall using the values file:

```bash
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  -f defectdojo-values.yaml
```

**Upgrade procedure:**
1. Back up the DefectDojo PostgreSQL database before any upgrade: `kubectl exec -n defectdojo deploy/defectdojo-postgresql -- pg_dump -U defectdojo defectdojo > defectdojo-backup-$(date +%Y%m%d).sql`
2. Review the release notes at https://github.com/DefectDojo/django-DefectDojo/releases for breaking changes or migration steps
3. Update `tag` in `defectdojo-values.yaml` to the new version
4. Run: `helm upgrade defectdojo defectdojo/defectdojo --namespace defectdojo -f defectdojo-values.yaml`

**Or Docker Compose:**

```bash
git clone https://github.com/DefectDojo/django-DefectDojo
cd django-DefectDojo
./docker/docker-compose-check.sh
docker compose up -d
docker compose logs initializer | grep "Admin password"
```

> **Version pinning for Docker Compose:** The default `docker-compose.yml` may reference `latest` tags. Before deploying, edit the compose file to pin the DefectDojo image to a specific version tag (e.g., `defectdojo/defectdojo-django:2.x.y`). Check https://github.com/DefectDojo/django-DefectDojo/releases for the current stable version. Commit the modified compose file to version control alongside a record of which version is deployed.
```

---

### CHANGE 3.3 — Pin DefectDojo tag in Phase 3b deployment block

FIND (exact text to locate in the document):
```
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  --set django.ingress.enabled=true \
  --set host="defectdojo.local" \
  --set tag="latest"

kubectl get secret defectdojo -n defectdojo \
  -o jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 -d

kubectl port-forward -n defectdojo svc/defectdojo-django 8080:80
```

Note to implementer: This FIND string appears twice in the document — once in Section 8 (Tool Details) and once in Phase 3b. Change 3.1 addresses the first occurrence. This change addresses the second occurrence (in Phase 3b). Because the surrounding context differs, the implementer should use the surrounding lines to distinguish them. The Phase 3b occurrence is preceded by these lines:

```
#### Phase 3b — DefectDojo

```bash
helm repo add defectdojo \
  https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts
helm repo update
```

REPLACE WITH:
```
# Replace 2.x.y with the current stable release from:
# https://github.com/DefectDojo/django-DefectDojo/releases
# Use defectdojo-values.yaml (see Section 8 — DefectDojo) rather than --set flags
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  -f defectdojo-values.yaml
```

---

## FEATURE 8 — Nexus Configuration Honesty

### CHANGE 8.1 — Replace "Controls what enters your supply chain" bullet with accurate framing

FIND (exact text to locate in the document):
```
- **Controls what enters your supply chain** — configure Nexus to only serve vetted/approved packages.
```

REPLACE WITH:
```
- **Provides a single audit and caching point for all upstream package traffic** — every `npm install`, `pip install`, and `docker pull` flows through one place, creating a complete record of what was fetched and when. This is an audit point, not a security boundary.

  **What Nexus does NOT do by default:** Nexus Community Edition does not scan content for vulnerabilities. A compromised upstream package flows through Nexus to your build unmodified. Scanning is the responsibility of Grype and Trivy. Controlling what enters the supply chain beyond caching requires additional policy configuration: content selectors, repository blocking rules, or allowlist-only hosted repositories. The default proxy configuration described here provides visibility and caching, not content enforcement.
```

---

### CHANGE 8.2 — Add a note after the npm proxy curl command block explaining the contentMaxAge: -1 tradeoff

FIND (exact text to locate in the document):
```
# PyPI proxy
curl -X POST "${NEXUS_URL}/service/rest/v1/repositories/pypi/proxy" \
  -u "${NEXUS_AUTH}" -H "Content-Type: application/json" \
  -d '{
    "name": "pypi-proxy", "online": true,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
    "proxy": {"remoteUrl": "https://pypi.org", "contentMaxAge": -1, "metadataMaxAge": 1440},
    "negativeCache": {"enabled": true, "timeToLive": 1440},
    "httpClient": {"blocked": false, "autoBlock": true}
  }'
```

REPLACE WITH:
```
# PyPI proxy
curl -X POST "${NEXUS_URL}/service/rest/v1/repositories/pypi/proxy" \
  -u "${NEXUS_AUTH}" -H "Content-Type: application/json" \
  -d '{
    "name": "pypi-proxy", "online": true,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
    "proxy": {"remoteUrl": "https://pypi.org", "contentMaxAge": -1, "metadataMaxAge": 1440},
    "negativeCache": {"enabled": true, "timeToLive": 1440},
    "httpClient": {"blocked": false, "autoBlock": true}
  }'
```

> **`contentMaxAge: -1` tradeoff:** Setting `contentMaxAge` to `-1` means Nexus caches package content indefinitely without rechecking the upstream registry. This improves build reproducibility (the same package version always resolves to the same cached artifact) and protects against upstream outages. The downside: if an upstream package is compromised and later patched or yanked, the compromised version persists in the Nexus cache until it is manually purged. For each repository, you can set a shorter TTL (e.g., `86400` for 24 hours) to limit this exposure window, at the cost of additional upstream traffic and reduced reproducibility. The Grype and Trivy scans in CI are the primary mechanism for detecting compromised packages that have been cached.
```

---

### CHANGE 8.3 — Add Group Repository Ordering note after the Supported Repository Formats table

FIND (exact text to locate in the document):
```
| Conan | ✅ | ✅ | — |
| R | ✅ | ✅ | ✅ |
| Raw | ✅ | ✅ | ✅ |

---

### 7. Harbor — Container Registry [Optional]
```

REPLACE WITH:
```
| Conan | ✅ | ✅ | — |
| R | ✅ | ✅ | ✅ |
| Raw | ✅ | ✅ | ✅ |

#### Group Repository Ordering and Dependency Confusion Protection

When using Nexus group repositories (npm-group, pypi-group, etc.) that combine a hosted repository with a proxy repository, **repository ordering matters for dependency confusion protection**.

Dependency confusion is an attack where a maliciously named package on the public registry (npmjs.org, pypi.org) shares the name of an internal package. If the proxy repository is searched before the hosted repository, the upstream attacker-controlled package wins.

Always place hosted (internal) repositories **before** proxy (upstream) repositories in the group member list:

```
Correct order (internal-first):
  Group members: [my-internal-npm-hosted, npm-proxy]
  → A package found in the hosted repo is returned immediately; upstream is never consulted

Wrong order (upstream-first):
  Group members: [npm-proxy, my-internal-npm-hosted]
  → An attacker who publishes a higher-version package to npmjs.org under your internal package name wins
```

Configure group member ordering in the Nexus UI: Repository → your-group-repo → Group → Members → drag hosted repositories above proxy repositories. This does not affect packages that only exist upstream; it only matters when the same name exists in both locations.

---

### 7. Harbor — Container Registry [Optional]
```

---

## FEATURE 10 — DefectDojo API Token Security

### CHANGE 10.1 — Replace plaintext DD_TOKEN in the "Importing scan results" block (Section 8 — DefectDojo)

FIND (exact text to locate in the document):
```
DD_URL="http://localhost:8080"
DD_TOKEN="your-api-token"

# Import Semgrep
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Semgrep JSON Report" \
  -F "file=@semgrep-results.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"
```

REPLACE WITH:
```
DD_URL="http://localhost:8080"
DD_TOKEN="${DEFECTDOJO_API_TOKEN:-your-api-token}"  # Set via environment variable or GitHub Actions secret

# Import Semgrep
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Semgrep JSON Report" \
  -F "file=@semgrep-results.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"
```

---

### CHANGE 10.2 — Add credentials note after the closing curl block in the Importing scan results section

FIND (exact text to locate in the document):
```
# Import Gitleaks
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Gitleaks Scan" \
  -F "file=@gitleaks-report.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"
```

REPLACE WITH:
```
# Import Gitleaks
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Gitleaks Scan" \
  -F "file=@gitleaks-report.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"
```

> **Credentials:** Never hardcode API tokens in scripts or commit them to version control. In GitHub Actions, store the token as a repository secret:
> Settings → Secrets and variables → Actions → New repository secret
> Name it `DEFECTDOJO_API_TOKEN`. Reference it in workflows as `${{ secrets.DEFECTDOJO_API_TOKEN }}`.
> Retrieve your DefectDojo API token from the DefectDojo UI: Profile → API v2 Key.

---

### CHANGE 10.3 — Replace plaintext DD_TOKEN in the GitHub Actions import script block

FIND (exact text to locate in the document):
```
#!/bin/bash
DD_URL="http://localhost:8080"
DD_TOKEN="your-token"
PRODUCT="My App"
ENGAGEMENT="CI-$(date +%Y%m%d)"
```

REPLACE WITH:
```
#!/bin/bash
DD_URL="http://localhost:8080"
DD_TOKEN="${DEFECTDOJO_API_TOKEN:-your-api-token}"  # Set via environment variable or GitHub Actions secret
PRODUCT="My App"
ENGAGEMENT="CI-$(date +%Y%m%d)"
```

---

### CHANGE 10.4 — Replace plaintext NEXUS_AUTH in the REST API section

FIND (exact text to locate in the document):
```
NEXUS_URL="http://localhost:8081"
NEXUS_AUTH="admin:your-password"
```

REPLACE WITH:
```
NEXUS_URL="http://localhost:8081"
NEXUS_AUTH="admin:${NEXUS_PASSWORD:-your-password}"  # Set NEXUS_PASSWORD as an environment variable
```

---

## FEATURE 11 — Alert Fatigue and Triage Guidance

### CHANGE 11.1 — Add "Managing Finding Volume" subsection after the "What DefectDojo gives you" paragraph

FIND (exact text to locate in the document):
```
**What DefectDojo gives you:** Consolidated view of all findings, automatic deduplication, finding lifecycle tracking (Open → Under Review → Mitigated → Closed), trending dashboards, per-product/engagement views, SLA tracking, and JIRA integration.

---

### 9. SonarQube Community Build — Code Quality + SAST Dashboard [Optional]
```

REPLACE WITH:
```
**What DefectDojo gives you:** Consolidated view of all findings, automatic deduplication, finding lifecycle tracking (Open → Under Review → Mitigated → Closed), trending dashboards, per-product/engagement views, SLA tracking, and JIRA integration.

#### Managing Finding Volume

This stack generates findings faster than a single developer can triage on first run. Independent operational analysis estimates 125–750 findings per repository across all scanners combined, depending on codebase size, IaC complexity, and how many dependencies are in use. Without a triage process, DefectDojo quickly becomes a write-only database — findings accumulate, nothing gets closed, and the tool stops informing decisions.

The following practices make the stack sustainable:

**Suppress pre-existing IaC findings with a Checkov baseline.** On first run, the majority of Checkov findings will be pre-existing issues unrelated to the current PR. Use the baseline workflow (documented in the Checkov section above) to snapshot the current state and focus only on new findings going forward:

```bash
# Run once in each repository to establish the baseline
checkov -d . --create-baseline
# Commit .checkov.baseline to the repository
# Subsequent runs: checkov -d . --baseline .checkov.baseline
```

See the Checkov baseline workflow above for full details.

**Enable DefectDojo deduplication.** DefectDojo's deduplication engine merges identical findings from multiple scanners (e.g., the same CVE reported by both Trivy and Grype). Configure it per product: DefectDojo UI → Products → select product → Edit → Deduplication algorithm → select the algorithm appropriate for your scanner combination (typically "Legacy" for general use). Without deduplication enabled, the same vulnerability appears multiple times and inflates apparent finding volume.

**Filter by severity on first triage pass.** Configure DefectDojo to auto-close or suppress Info and Low severity findings initially. The first triage pass should focus exclusively on Critical and High findings. Medium findings are a second pass. Info/Low findings can be reviewed in bulk monthly or suppressed by rule if they are not actionable for this codebase. Severity auto-close rules: DefectDojo UI → System Settings → Finding Auto-Close.

**Establish a weekly time-boxed triage cadence.** Rather than triaging every finding as it arrives, reserve a fixed time window each week — 30 minutes is sufficient for steady-state once the initial backlog is addressed. Review new Critical/High findings from the past week, close or accept anything that is a known false positive, and mark duplicates. This cadence prevents the triage backlog from compounding while keeping the investment predictable and sustainable.

A written triage SOP — even a short checklist — is the difference between a security program and a security dashboard. Without it, DefectDojo becomes infrastructure that nobody looks at.

---

### 9. SonarQube Community Build — Code Quality + SAST Dashboard [Optional]
```

---

## Implementation Notes for the Applying Agent

1. **Change 3.3** (Phase 3b tag pinning): The Helm install block for DefectDojo appears twice in the document — once in Section 8 (Tool Details, lines ~573-578) and once in Phase 3b (lines ~1404-1409). Change 3.1 targets the first occurrence; Change 3.3 targets the second. The surrounding context makes them distinguishable. The Phase 3b instance is immediately preceded by `helm repo update` (the `helm repo add defectdojo` block) and followed by the `kubectl get secret` and `kubectl port-forward` commands and then the "After DefectDojo is healthy..." prose paragraph.

2. **Change 10.1 vs 10.3**: Both reference `DD_TOKEN` but in different code blocks. Change 10.1 targets the individual curl examples in Section 8. Change 10.3 targets the bash loop script under "Import script for DefectDojo" in the GitHub Actions section. The FIND strings are distinct enough to identify them unambiguously.

3. **Feature 8, Change 8.2**: The `contentMaxAge: -1` note is inserted after the PyPI proxy curl block specifically (chosen because it is a clean anchor point in the middle of the REST API section). The tradeoff applies equally to npm, Docker, and Helm proxy blocks — the note makes this explicit by referencing "each repository."

4. **All FIND strings** have been verified as verbatim copies from the source document as read during this session.
