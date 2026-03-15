# Pitfalls Research

**Domain:** Zero-cost self-hosted developer security and supply chain scanning stack
**Researched:** 2026-03-15
**Confidence:** HIGH (primary source is the project's own red-team analysis of 15 convergent findings, verified against community experience)

## Critical Pitfalls

### Pitfall 1: Advisory-Only CI Gates (The "Green Check" Illusion)

**What goes wrong:**
Scanner steps configured with `continue-on-error: true` always report success. A PR with 200 critical findings looks identical to a clean one. The CI pipeline appears to enforce security but blocks nothing.

**Why it happens:**
Developers copy CI workflow examples that use `continue-on-error` to prevent pipeline failures during initial setup. The flag stays forever because "the pipeline works" and removing it would break existing workflows. The project's own red-team found this was the single most impactful issue — all three independent analysts flagged it.

**How to avoid:**
- Remove `continue-on-error: true` from all scanner execution steps from day one (ADR-001)
- Add severity-based failure thresholds: `grype --fail-on high`, `semgrep --error`, `checkov --soft-fail false`
- Retain `continue-on-error` only on SARIF upload and artifact upload steps (reporting infra, not enforcement)
- Validate by deliberately introducing a known vulnerability and confirming the PR check fails

**Warning signs:**
- All PR security checks show green even on a repo with known issues
- No developer has ever been blocked by a security finding
- Scanner logs show findings but the workflow step shows "passed"

**Phase to address:** M2 (CI/CD Security Gate) — this is the enforcement layer and must be blocking from the start

---

### Pitfall 2: CI Gates Without Branch Protection (Enforcement Without a Lock)

**What goes wrong:**
Even with properly failing scanner steps, developers can push directly to `main` bypassing all PR-based scanning. Without branch protection, the CI gate has zero enforcement effect — it only runs on PRs, and PRs are optional.

**Why it happens:**
Branch protection is a manual GitHub settings step, not a code artifact. It gets deferred because "we'll add it later" or forgotten because it is outside the normal code-and-deploy workflow. The CI YAML gets all the attention; the GitHub settings page does not.

**How to avoid:**
- Configure branch protection as part of M2 deployment, not after (ADR-002)
- Enable: require PR before merging, require status checks to pass, block direct pushes to `main`, do not allow bypassing settings
- Validate: attempt `git push origin main` directly — GitHub must reject it
- Validate: open a PR with a failing required status check — merge button must be disabled

**Warning signs:**
- `git push origin main` succeeds from a local branch
- PRs with failing checks can still be merged
- Branch protection rules page shows no rules configured

**Phase to address:** M2 (CI/CD Security Gate) — must be a required deliverable, not an optional follow-up

---

### Pitfall 3: Finding Volume Overwhelm (The Write-Only Dashboard)

**What goes wrong:**
First-run security scans generate 125-750+ findings per repository. Without triage strategy, DefectDojo becomes a write-only database. The developer abandons triage because the volume is unmanageable, and the entire stack's value proposition collapses — tools run, findings accumulate, nothing gets fixed.

**Why it happens:**
Legacy codebases have accumulated years of issues. IaC scanning (Checkov) flags every deviation from best practice, including intentional ones. Without baselines, every existing issue looks like a new finding. A single developer cannot process hundreds of findings per week on top of feature work.

**How to avoid:**
- Run `checkov --create-baseline` on existing repos before enabling CI gates — only new findings get flagged (M2)
- Configure DefectDojo deduplication rules so duplicate findings across scanners are collapsed (M4)
- Set severity-based auto-close for INFO/LOW findings in DefectDojo (M4)
- Establish a weekly time-boxed triage cadence (30 minutes) — do not attempt to clear the backlog in one session
- Focus on HIGH/CRITICAL only for the first month; expand to MEDIUM after the initial surge stabilizes

**Warning signs:**
- DefectDojo finding count climbs weekly but "active" count never decreases
- Developer stops checking DefectDojo dashboard
- No findings have been closed or risk-accepted in over two weeks
- CI pipeline has dozens of suppressed/ignored findings with no documentation

**Phase to address:** M4 (DefectDojo) for triage workflow setup; M2 (CI/CD) for baseline creation on existing repos

---

### Pitfall 4: Silent Security Tool Failures (The False Coverage Illusion)

**What goes wrong:**
Security tools crash, databases go stale, import pipelines break — but nothing alerts. The dashboard shows the last known state as if it were current. Scans stop running but the security picture looks clean. The absence of alerts is indistinguishable from a clean environment.

**Why it happens:**
Security tooling is deployed as infrastructure but not monitored as infrastructure. Monitoring is deferred to "later" because it is not security functionality per se. Trivy Operator stops updating its vulnerability database, DefectDojo imports fail silently, Nexus fills its disk — all invisible without alerting.

**How to avoid:**
- Deploy monitoring (kube-prometheus-stack) in M5 as a hard requirement, not optional
- Four minimum alert conditions: Nexus disk usage threshold, DefectDojo import failures (stale last-import timestamp), Trivy Operator database staleness, pod CrashLoopBackOff in any security namespace
- Enable Nexus Prometheus metrics endpoint (`/service/metrics/prometheus`)
- Test alerting: kill a security pod and confirm the alert fires within the configured interval

**Warning signs:**
- No one can say when the last successful DefectDojo import ran
- `kubectl get pods -n defectdojo` shows CrashLoopBackOff but no one noticed
- Vulnerability counts have not changed in weeks (either everything is clean or nothing is scanning)
- Nexus disk usage is unknown

**Phase to address:** M5 (Infrastructure Hardening) — monitoring is the difference between development-grade and production-grade

---

### Pitfall 5: Plaintext Credentials in Security Tooling

**What goes wrong:**
DefectDojo API tokens, Nexus admin passwords, and other credentials get hardcoded in scripts, CI workflows, or Helm values files committed to version control. A compromised DefectDojo API token gives read/write access to the complete vulnerability inventory — the most sensitive output of the entire stack.

**Why it happens:**
Documentation examples use placeholder tokens (`DD_TOKEN="your-api-token"`). Developers copy-paste and replace the placeholder with a real token in the same file. The file gets committed. The token is now in git history forever. ADR-005 was created specifically because the project's own reference document had this pattern.

**How to avoid:**
- All script examples must use environment variable syntax: `${DEFECTDOJO_API_TOKEN}`, never literal values
- GitHub Actions must use `${{ secrets.DEFECTDOJO_API_TOKEN }}` — store tokens as repository secrets
- Gitleaks pre-push hook catches tokens before they reach the remote (but can be bypassed — see Pitfall 6)
- Gitleaks CI job catches tokens server-side as a compensating control
- Never commit Helm values files containing passwords; use `--set` flags referencing environment variables or external secrets

**Warning signs:**
- `grep -r "token\|password\|secret" *.yaml *.sh` in the repo returns literal credential values
- Gitleaks findings for the repo's own CI scripts
- DefectDojo API token appears in GitHub Actions logs

**Phase to address:** M2 (CI/CD) for secrets scanning; M4 (DefectDojo) for API token handling; M3 (Nexus) for admin credential handling

---

### Pitfall 6: Over-Reliance on Pre-Commit Hooks as Security Enforcement

**What goes wrong:**
Pre-commit hooks (including Gitleaks secrets detection) are treated as the security enforcement layer, but `git commit --no-verify` and `git push --no-verify` bypass all hooks with a single flag. The entire pre-commit framework runs client-side with zero server-side enforcement.

**Why it happens:**
Pre-commit hooks feel like enforcement because they block the developer workflow. The mental model is "it runs before every commit, so nothing gets through." The bypass flags are rarely mentioned in pre-commit documentation and are easy to overlook.

**How to avoid:**
- Frame pre-commit hooks as defense-in-depth (early catch), not enforcement (ADR-011)
- The CI/CD layer (GitHub Actions) is the actual enforcement layer — Gitleaks runs server-side on every PR
- Branch protection with required status checks is the mechanism that cannot be bypassed client-side
- Document the bypass risk explicitly so the developer maintains an accurate mental model

**Warning signs:**
- No CI-level secrets scanning — only pre-commit Gitleaks
- Developer documentation describes pre-commit as "preventing secrets from being committed" without qualification
- No branch protection configured (pre-commit is the only "gate")

**Phase to address:** M1 (Workstation) for hook setup with accurate framing; M2 (CI/CD) for the compensating server-side control

---

### Pitfall 7: Nexus Blob Store Disk Exhaustion

**What goes wrong:**
The Nexus `/nexus-data` PVC fills up, corrupting the blob store and locking the database in read-only mode. Once the blob store enters a failed state after disk exhaustion, it can appear permanently corrupted even after freeing space. Builds fail silently as packages cannot be cached.

**Why it happens:**
Nexus with `contentMaxAge: -1` caches packages indefinitely. Across npm, PyPI, Docker images, and Helm charts, cached artifacts accumulate without bound. Nexus cleanup policies are not configured by default. The PVC size chosen at deployment time seems adequate initially but fills over months.

**How to avoid:**
- Configure Nexus cleanup policies from deployment (retention by age, usage, or both)
- Use a StorageClass with `allowVolumeExpansion: true` so PVC resizing is possible
- Add Nexus disk usage to Prometheus alerting (M5-F4) — alert well before full
- Separate blob store from the Nexus data directory for operational isolation
- Enable the Nexus Prometheus metrics endpoint for monitoring

**Warning signs:**
- `kubectl exec` into Nexus pod and check `df -h /nexus-data` — approaching 80%+ usage
- Builds intermittently fail to pull cached packages
- Nexus UI shows blob store in "Failed" state
- `npm install` or `pip install` times out through Nexus proxy

**Phase to address:** M3 (Nexus deployment) for initial sizing and cleanup policies; M5 (Hardening) for monitoring and alerting

---

### Pitfall 8: NetworkPolicy Silently Ignored by CNI

**What goes wrong:**
NetworkPolicy objects are applied to namespaces but have zero effect because the cluster's CNI plugin does not support them. The policies exist in `kubectl get networkpolicy` output, creating the appearance of network isolation that does not actually exist. Default Kubernetes allows all pod-to-pod traffic across namespaces.

**Why it happens:**
Clusters using the default Kubenet CNI (common in some managed K8s offerings and lightweight distributions) silently ignore NetworkPolicy objects. There is no error, no warning — the objects are accepted and stored but never enforced. ADR-008 documents this explicitly.

**How to avoid:**
- Verify CNI before deploying any NetworkPolicies: `kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'`
- If no supported CNI is found, install one (Calico or Cilium are the standard choices) before M5
- Test enforcement: create a deny policy, then try to connect from a blocked pod — connection must time out or be refused
- Never assume policies work just because they were applied without error

**Warning signs:**
- `kubectl get networkpolicy -A` returns policies but `kubectl get pods -n kube-system` shows no Calico/Cilium/Weave pods
- A test pod in a "blocked" namespace can still reach services in another namespace
- NetworkPolicy objects were applied but no connectivity changes were observed

**Phase to address:** M5-F1 (NetworkPolicy Isolation) — CNI verification is a hard prerequisite

---

### Pitfall 9: Unpinned GitHub Actions Enable Supply Chain Attacks

**What goes wrong:**
GitHub Actions referenced by mutable semver tags (`@v4`, `@master`) can be silently updated by the action maintainer or by an attacker who compromises the action repository. A tampered action executes with access to source code, repository secrets, and the DefectDojo API token.

**Why it happens:**
Every GitHub Actions tutorial and example uses `@v4` style tags. SHA pinning is ugly, breaks readability, and makes updates harder. The risk feels theoretical until it is not. The compromise of the `tj-actions/changed-files` action in March 2025 demonstrated real-world exploitation of this exact vector.

**How to avoid:**
- Pin all GitHub Actions to full SHA digest from day one (ADR-004)
- Use Dependabot or Renovate for automated SHA digest updates — this solves the maintenance burden
- Add comments next to SHA pins indicating the version for readability: `uses: actions/checkout@<SHA>  # v4`
- Never use `@master` or `@main` tags for any action

**Warning signs:**
- `grep -r "@v[0-9]" .github/workflows/` returns results (mutable tags in use)
- No Dependabot or Renovate configuration for GitHub Actions updates
- Actions referenced by `@master` or `@main` tags

**Phase to address:** M2 (CI/CD Security Gate) for initial pinning; M5-F5 (Version Update Process) for ongoing maintenance via Dependabot

---

### Pitfall 10: Kyverno Enforce Mode Before Audit (Breaking All Deployments)

**What goes wrong:**
Kyverno admission policies deployed in `Enforce` mode immediately block all images that do not match the policy. If existing workloads use unsigned images (which they will before Cosign signing is fully rolled out), every pod restart, scale event, or deployment update fails. The cluster becomes unable to schedule workloads.

**Why it happens:**
The policy definition includes `validationFailureAction: Enforce` which is the desired end state. Deploying the policy as-is before confirming all images are signed creates an immediate availability crisis. The blast radius is every namespace the policy applies to.

**How to avoid:**
- Deploy Kyverno with `validationFailureAction: Audit` first — always
- Review audit findings: `kubectl get policyreport -A` to confirm only expected images are in use
- Sign all images with Cosign in CI before switching any namespace to Enforce
- Switch to Enforce namespace-by-namespace, not cluster-wide
- Exclude system namespaces (kube-system, cert-manager, monitoring) from the policy or add explicit exceptions

**Warning signs:**
- `kubectl get policyreport -A` shows violations for core infrastructure images
- Pods fail to schedule with admission webhook errors
- Helm upgrades for infrastructure components fail after Kyverno deployment

**Phase to address:** M6 (Runtime Security) — Cosign signing must be working in CI before Kyverno switches to Enforce

---

### Pitfall 11: Falco Default Rules Generate Excessive Noise

**What goes wrong:**
Falco's default ruleset generates hundreds of alerts for normal Kubernetes operations — system processes, health checks, log rotation, package managers in init containers. The alert volume makes it impossible to identify genuine threats. The developer disables Falco or ignores its output entirely.

**Why it happens:**
Falco's default rules are broad by design to catch as many potential threats as possible. They are not tuned for any specific cluster. Normal operations like `kubectl exec` for debugging, cert-manager renewal, and monitoring agent scraping all trigger alerts.

**How to avoid:**
- Start with Falco rules at DEBUG/INFO priority, not WARNING/ERROR — observe what fires for a week before escalating
- Write custom rules scoped to security-stack namespaces rather than relying on default rules
- Add exceptions for known-good processes: cert-manager, monitoring agents, init containers
- Use FalcoSidekick to route alerts to a channel where they can be reviewed, not directly to a pager
- Test rules in a non-production window: run normal operations and review what triggers

**Warning signs:**
- Falco generates more than 50 alerts per day in a quiet single-developer cluster
- Most alerts are from system processes or monitoring infrastructure
- No custom rule exceptions have been added after initial deployment
- FalcoSidekick output is being ignored

**Phase to address:** M6 (Runtime Security) — rule tuning is part of deployment, not a separate task

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `insecure-registries` for Nexus Docker proxy | Fast initial setup, no TLS complexity | All Docker pulls through Nexus are MITM-able; packages can be intercepted and replaced | Only during M3 initial setup; must be removed in M5-F2 |
| `trusted-host` in pip config | pip works without TLS against Nexus | Same as above for Python packages | Only during M3; remove in M5-F2 |
| Helm `tag="latest"` for DefectDojo/Nexus | Always runs newest version | Pod restart pulls new major version with breaking schema migrations; import pipeline breaks; findings database can corrupt | Never — pin to specific version tags from day one (ADR-006) |
| Skipping Checkov baseline for existing repos | CI pipeline passes immediately | Every pre-existing IaC issue floods DefectDojo; developer is overwhelmed from day one | Never for repos with existing IaC code |
| Manual version tracking of 30+ components | No Dependabot/Renovate setup time | Falls months behind within a year; security tools themselves accumulate vulnerabilities | Never — automate from M2 onward |
| Deferring monitoring to "after everything works" | Faster time to initial deployment | Silent failures create false confidence; the stack can be broken for weeks without notice | M5 is the latest acceptable milestone for monitoring |

## Integration Gotchas

Common mistakes when connecting components of this stack.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CI to DefectDojo import | Using external URL from CI runner pods inside K8s | Use internal cluster URL: `http://defectdojo-django.defectdojo.svc.cluster.local:80` |
| Nexus group repository ordering | Proxy (upstream) repo listed before hosted (internal) repo | Hosted repo must be first in group — prevents dependency confusion attacks (ADR-010) |
| DefectDojo Helm reinstallation | `secrets 'defectdojo' already exists` error | Add `--set createSecret=false` if reinstalling after a previous Helm release |
| Workstation package managers to Nexus | Configuring npm/pip/Docker to use Nexus without testing fallback | Test that builds still work if Nexus is temporarily down — configure upstream as fallback or accept the coupling |
| Kyverno + Cosign | Deploying Kyverno Enforce before all CI pipelines sign images | Deploy Audit mode first; sign all images in all CI pipelines; verify `policyreport` is clean; then switch to Enforce |
| Falco + security tool pods | Falco rules fire on DefectDojo, Nexus, cert-manager normal operations | Add explicit exceptions for known security tool pod behavior before enabling rules |
| SARIF upload to GitHub Security tab | Uploading SARIF only on success (missing `if: always()`) | SARIF upload steps must use `if: always()` so findings are visible even when the scanner step fails |

## Performance Traps

Patterns that work initially but degrade over time.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Nexus caching everything indefinitely (`contentMaxAge: -1`) | Disk fills over months; blob store enters failed state | Configure cleanup policies; monitor disk usage; use expandable PVC | 3-6 months depending on dependency count |
| DefectDojo with thousands of unprocessed findings | Dashboard loads slowly; API imports time out; triage is impossible | Deduplication rules, auto-close for low severity, baseline existing repos | After scanning 3-6 repos with existing issues |
| Running all security scans sequentially in CI | 15-20 minute PR pipeline; developer context-switches during wait | Run scans in parallel jobs (the workflow already uses 5 parallel jobs) | Immediate if sequential; parallel keeps it under 5 minutes |
| Pre-commit hooks with too many Tier 1 checks | Commits take 10+ seconds; developer starts using `--no-verify` | Keep pre-commit under 5 seconds total; move expensive checks to CI | When total hook time exceeds developer patience (~5-10 seconds) |
| Falco with default ruleset on active cluster | Hundreds of alerts per day; all signal lost in noise | Custom rules scoped to security namespaces; start at DEBUG priority | Immediately on deployment with default rules |

## Security Mistakes

Domain-specific security issues for a self-hosted security scanning stack.

| Mistake | Risk | Prevention |
|---------|------|------------|
| DefectDojo API accessible from all namespaces | Attacker reads complete vulnerability inventory — perfect reconnaissance | NetworkPolicy default-deny ingress on defectdojo namespace (M5-F1) |
| Nexus API accessible from all namespaces | Attacker uploads malicious packages into cache; all developers install them | NetworkPolicy isolation + Nexus admin password in K8s Secret, not in values file |
| DefectDojo admin password unchanged from Helm default | Full admin access to all findings, users, and configuration | Change default password on first login; rotate periodically |
| Monitoring stack itself unmonitored | If Prometheus/Alertmanager goes down, all other alerting stops working | Configure a dead-man's switch alert or external health check for Alertmanager |
| Falco rules writable by application pods | Attacker disables detection rules before performing malicious activity | Falco runs in its own namespace with RBAC; rules stored in ConfigMaps accessible only to falco-system |
| Cosign key material in CI environment | Stolen signing key allows attacker to sign malicious images that pass Kyverno | Use keyless signing (Fulcio + Rekor) — no persistent key material; signatures are tied to OIDC identity |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical verification.

- [ ] **CI Security Gate:** Scans pass green -- verify a known vulnerability actually fails the check (not just `continue-on-error` hiding failures)
- [ ] **Branch Protection:** Rules configured -- verify direct push to main is actually rejected (test it, do not assume)
- [ ] **NetworkPolicy:** Policies applied -- verify CNI supports them and a blocked pod actually cannot connect
- [ ] **TLS:** cert-manager running -- verify `insecure-registries` and `trusted-host` are actually removed from workstation configs
- [ ] **Backups:** CronJob exists -- verify a restore actually works (backup without tested restore is not a backup)
- [ ] **Monitoring alerts:** Alertmanager configured -- verify a test alert actually routes to the destination (kill a pod and check)
- [ ] **Nexus proxy:** Package installs work -- verify the hosted repo is ordered before proxy in the group (dependency confusion protection)
- [ ] **Kyverno:** Policy exists -- verify it is in Enforce mode (not still in Audit) for production namespaces after signing is confirmed
- [ ] **DefectDojo imports:** Pipeline configured -- verify findings actually appear in DefectDojo (not failing silently)
- [ ] **Gitleaks CI:** Workflow step exists -- verify it catches a test secret (not passing because of misconfigured patterns)

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Advisory-only CI gates discovered late | LOW | Add `--fail-on` flags to scanner commands; remove `continue-on-error`; existing findings need baseline or bulk triage |
| Secrets committed to git history | HIGH | Rotate all exposed credentials immediately; use `git filter-repo` or BFG to remove from history; force-push (coordinate if others have cloned) |
| Nexus blob store corruption from disk full | MEDIUM | Restore from PVC snapshot (if available); if not, delete and recreate Nexus — cached packages re-download from upstream |
| DefectDojo database corruption from unpinned upgrade | HIGH | Restore from `pg_dump` backup; if no backup, rebuild from scratch — all historical findings lost |
| Kyverno Enforce blocking all deployments | LOW (if fast) | Change `validationFailureAction` to `Audit` immediately; investigate which images lack signatures; fix and re-enable |
| Falco alert fatigue causing all alerts to be ignored | LOW | Reset to custom minimal ruleset; re-enable rules one by one with exceptions; use Audit before Warning |
| Finding volume overwhelming the developer | MEDIUM | Create Checkov baselines retroactively; bulk-close INFO/LOW in DefectDojo; establish triage time-box; accept risk on legacy findings |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Advisory-only CI gates | M2 (CI/CD) | Deliberately introduce a vulnerability; confirm PR check fails and merge is blocked |
| Missing branch protection | M2 (CI/CD) | `git push origin main` directly — must be rejected |
| Finding volume overwhelm | M2 (baselines) + M4 (triage) | After 2 weeks: active findings count is manageable; triage cadence is maintained |
| Silent tool failures | M5 (Monitoring) | Kill a security pod; confirm alert fires within configured interval |
| Plaintext credentials | M2 (secrets scanning) + M3/M4 (credential handling) | `gitleaks detect` on all repos returns clean |
| Pre-commit bypass reliance | M1 (framing) + M2 (enforcement) | CI catches a test secret even when pre-commit is bypassed |
| Nexus disk exhaustion | M3 (cleanup policies) + M5 (monitoring) | Nexus disk usage alert fires when threshold is crossed |
| NetworkPolicy ignored by CNI | M5-F1 | Test pod in blocked namespace cannot reach DefectDojo API |
| Unpinned GitHub Actions | M2 (initial setup) + M5-F5 (Dependabot) | `grep -r "@v[0-9]" .github/workflows/` returns no results |
| Kyverno Enforce before Audit | M6 | All images in `policyreport` are clean before switching from Audit to Enforce |
| Falco alert noise | M6 | Fewer than 10 meaningful alerts per day after one week of tuning |
| Unpinned Helm chart versions | M3 + M4 | Helm release pinned to specific version; `tag="latest"` not present in any values file |

## Sources

- Project red-team analysis: 15 convergent findings from three independent agents (internal document, February 2026)
- ADR-001 through ADR-014 in `docs/adr/` (project architectural decision records)
- Project main document `docs/development-security-stack-option-1.md` warnings and known gaps section
- [Adventures with Nexus in Kubernetes: database corruption and storage management](https://itnext.io/adventures-with-nexus-in-kubernetes-database-corruption-and-storage-management-c5c5118b5e86) — MEDIUM confidence
- [Day 2 Falco Container Security - Tuning the Rules](https://www.sysdig.com/blog/day-2-falco-container-security-tuning-the-rules) — MEDIUM confidence
- [Why Pre-Commit Hooks Fail at Stopping Secrets](https://xygeni.io/blog/why-pre-commit-hooks-fail-at-stopping-secrets/) — MEDIUM confidence
- [Blob store in permanent Failed state after running out of disk space](https://community.sonatype.com/t/blob-store-in-permanent-failed-state-after-running-out-of-disk-space/6882) — MEDIUM confidence
- [Falco 0.41.1 false positives for incubating rules](https://github.com/falcosecurity/falco/issues/3610) — HIGH confidence (official issue tracker)
- [DefectDojo Helm chart Kubernetes deployment](https://github.com/DefectDojo/django-DefectDojo/blob/master/readme-docs/KUBERNETES.md) — HIGH confidence (official repo)

---
*Pitfalls research for: zero-cost self-hosted developer security and supply chain scanning stack*
*Researched: 2026-03-15*
