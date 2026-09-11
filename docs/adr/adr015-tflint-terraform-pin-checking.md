# ADR-015: Adopt tflint for Terraform Provider and Module Pin Checking

**Status:** Accepted
**Date:** 2026-09-11
**Addresses:** SCA-03 — Terraform provider and module versions are checked for floating or unpinned constraints

## Context

The CI pipeline's `sca` job scans npm and Python dependency manifests, but nothing in the stack checked how Terraform declares its own supply chain: the provider versions in `required_providers` and the sources and versions of the modules a configuration pulls in. An unpinned provider or module is the same class of supply chain exposure as an unpinned package — the configuration that passes review today can resolve to different upstream code tomorrow.

**tflint has no prior precedent in this project.** It appears nowhere in `docs/development-security-stack-option-1.md`, nowhere in the workstation `versions.conf`, and in no earlier ADR (ADR-001 through ADR-014). Adopting it is a genuine addition to the stack, not a configuration change to something already present — which is why it gets a decision record rather than a line in a plan.

Two cheaper options were measured first, and both failed:

**Checkov cannot do this job, even though it is already running.** The IaC job runs Checkov on every pull request, so reusing it would have cost nothing. Measured during Phase 16 research:

- Checkov's Terraform pinning policies cover **modules only**. There is **no provider-pinning policy** in Checkov at all, so the "provider" half of SCA-03 is unreachable through it.
- `CKV_TF_1` additionally fails a registry module that is *correctly* pinned to an exact version (`version = "5.0.0"`), because the policy demands a git commit hash as the source revision. Applied to registry modules — which is how this stack consumes modules — it produces a finding on configurations that are already doing the right thing.

**A hand-rolled `grep` for `version =` is not viable.** HCL is block-structured, not line-oriented. The literal string `version =` appears inside `required_providers` entries, inside `module` blocks, and inside unrelated resource attributes that have nothing to do with pinning. A regex cannot tell which block it is standing in, so it would produce both false positives on ordinary resource arguments and false negatives on the multi-line forms. Parsing HCL correctly is the tool's job, not the pipeline's.

## Decision

**tflint v0.64.0 is adopted as the Terraform provider and module pin checker**, running in CI with its bundled `terraform` ruleset (v0.15.0 under this tflint version).

- **Installed by checksum-verified `.zip` download**, never `curl | sh`. The install step downloads `tflint_linux_amd64.zip` from the pinned release tag, verifies it with `sha256sum -c -` against a recorded digest, and unzips it into `/usr/local/bin`. This matches the existing Gitleaks precedent in `security.yml` and preserves ADR-004's intent — that what the pipeline executes is identified by a digest, not by a mutable URL — end to end. A third-party `setup-tflint` action was considered and rejected: it is convenient and Dependabot-trackable, but it widens the trust boundary by one more action for no gain the checksum does not already provide.
- **Invoked as `tflint --recursive`.** A repo-root invocation without it sees zero `.tf` files (tflint inspects only the current directory by default) and exits 0 — a silent false pass, which is the worst possible failure mode for a security check. `--recursive` is load-bearing, not stylistic.
- **Runs as a step inside the existing `sca` job, not as a new job.** The five check-run names produced by `security.yml` are load-bearing for branch protection; every new job would add a sixth name that a later phase's required-status-check list would have to absorb. Adding steps to an existing job leaves the published contract byte-identical.
- **CI-only for now.** tflint is deliberately *not* added to `versions.conf` and *not* added to the workstation installer. The local smoke gate (`scripts/smoke-scans.sh`) therefore probes for the binary and, when it is absent, prints a `SKIPPED:` message for its tflint sub-check and continues — a skipped sub-check is never counted as a passed one.

## Consequences

**Improved:** Terraform's own supply chain is now checked on every pull request, closing a gap no tool in the stack covered. On the live pipeline run (PR #7, run `34614017396`), tflint fired three rules against the fixture, two of them pinning rules:

- `terraform_required_providers` — *"Missing version constraint for provider `random` in `required_providers`"* (`fixtures/main.tf` line 16)
- `terraform_module_version` — *"module `fixture_unpinned_module` should specify a version"* (`fixtures/main.tf` line 38)
- `terraform_required_version` — the `terraform {}` block declares no `required_version` (a hygiene finding, **not** a pinning finding; it alone would not satisfy SCA-03)

Nothing in Checkov, Trivy, Semgrep or Grype reports any of these. The same three rule ids fired under the workstation's tflint 0.61.0 with bundled ruleset 0.14.1, so the CI/workstation version split introduced no rule drift on this configuration.

**Tradeoff — the default ruleset does not flag loose ranges.** This is the limitation that matters most, and it is stated here so no later reader infers coverage the tool does not provide. Measured:

| Construct | Flagged? | Rule |
|---|---|---|
| `version = "3.74.0"` — exact pin | no | *(correct — this is what a pin check wants)* |
| `source = "hashicorp/random"` — **no `version` key** | **yes** | `terraform_required_providers` |
| `version = ">= 3.0"` — **floating range** | **NO** | *not flagged by the default ruleset* |
| registry `module` block with no `version` | **yes** | `terraform_module_version` |
| git `module` source with no `ref`, or a default-branch `ref` | **yes** | `terraform_module_pinned_source` |
| `terraform {}` block with no `required_version` | yes | `terraform_required_version` (hygiene, not pinning) |

So SCA-03's phrase *"floating or unpinned versions are reported as findings"* is satisfied through **missing provider constraints and unpinned module sources only** — not through loose version ranges. A configuration that pins `version = ">= 3.0"` will pass this check while still resolving to arbitrary future provider releases.

Closing that gap would require a custom tflint rule, which is **explicitly out of scope** for this phase — and flagging the operator family wholesale would be very noisy, since `~>` is HashiCorp's own recommended practice for root modules. The honest position is that this check catches *absent* constraints and *unpinned* module sources, and that reviewing the tightness of a present constraint remains a human responsibility.

**Two further caveats on when the rules fire:**

- `terraform_required_providers` fires only when the provider is **actually used by a resource in the module**. A `required_providers` entry with no version and no consuming resource does not trigger it — a different rule (`terraform_unused_required_providers`, available under the `all` preset) reports that case instead. Any fixture proving this rule must both declare *and use* the unconstrained provider.
- `terraform_module_pinned_source` did **not** fire on the live run. It is a git-source rule, and the fixture's unpinned module uses a registry source, so the rule had nothing to apply to. Its behaviour above is from the Phase 16 research reproduction against git sources, not from run `34614017396` — the live evidence covers `terraform_required_providers` and `terraform_module_version` only.

**Tradeoff — tflint exits 2 on findings, not 1.** Unlike npm audit and pip-audit, which return 1, tflint's documented findings code is 2; an exit of 1 from tflint means an application error, not a finding. This required generalising the local smoke gate's verdict helper to take the expected findings exit code as a parameter (`run_scan_rc 2 "tflint" …`) rather than assuming 1. In CI the step carries `continue-on-error: true`, consistent with the report-only posture the pipeline holds until the gating phase, and the verdict is asserted from the SARIF report's rule ids rather than from the exit code — a report-content assertion cannot be satisfied by a tool that failed to run.
