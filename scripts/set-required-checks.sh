#!/usr/bin/env bash
set -euo pipefail

# set-required-checks.sh — read-modify-write helper that adds
# `required_status_checks` (the five byte-exact scan contexts, pinned to the
# GitHub Actions app) and a `pull_request` rule to the repository's existing
# branch ruleset, carrying every rule already present forward untouched.
#
# WHY THIS EXISTS. `PUT /repos/{owner}/{repo}/rulesets/{id}` REPLACES the
# whole document (RESEARCH P-05). A body carrying only the new rule silently
# deletes `deletion` and `non_fast_forward` from `main` — a security
# regression dressed as a security improvement. `required_status_checks`
# alone also does not require a pull request (RESEARCH P-09 / ADR-002), so a
# developer with write access could bypass the entire gate with one direct
# push; this helper always adds both rules together, never one alone.
#
# Never set the executable bit on this file (project rule
# .claude/rules/defensive-protocol-v2-anti-slop.md). Invoke as:
#   bash scripts/set-required-checks.sh [flags]
#
# Default behaviour is a DRY RUN: read the ruleset (or a captured file under
# --input), build the merged document, write it to --out, print a rule-type
# before/after comparison, exit 0, and touch NOTHING on GitHub. The live PUT
# only happens under an explicit --apply, and --apply itself requires a
# mandatory --verify-sha preflight plus an explicit
# --yes-i-understand-lockout acknowledgement (see EXIT CODES and the
# --apply guard below).
#
# ORDERING (D-07): confirm the five checks appear GREEN in report-only mode
# first, then flip `gh variable set GATE_MODE --body blocking` and observe
# them go RED, and only THEN run this script with --apply to make them
# required. Requiring an unobserved check is how a repo ends up with a
# permanently-pending required context (RESEARCH P-07).
#
# The five contexts below were read once, byte-exact, from the check-runs
# endpoint — never retyped from a code-scanning analysis name (the two
# disagree on case; STATE.md 17-05) and never hand-copied from documentation:
#
#   gh api repos/OttawaCloudConsulting/security-platform/commits/<SHA>/check-runs \
#     --jq '.check_runs[] | select(.app.id == 15368) | .name'
#
# run against SHA fbe0071d6934d19524f5bf9345e91396080fa882 (Phase 17 head).
# The separator in every context is EM DASH U+2014, never a hyphen and never
# the en dash U+2013 — confirmed by codepoint dump before this file was
# committed.
#
# EXIT CODES:
#   0  success — dry run produced its output file, or --apply's PUT and
#      read-back both succeeded
#   1  generic failure surfaced from a `gh api` or `python3` invocation
#   2  the fetched/input ruleset document has no `rules` key (a missing key
#      and an empty array mean different things — never treated as empty)
#   3  the merged document would drop a pre-existing rule type (the P-05
#      regression this script exists to prevent) — never written anywhere
#   4  --apply was passed without --verify-sha (mandatory preflight)
#   5  --apply was passed without --yes-i-understand-lockout
#   6  --verify-sha preflight found a context missing from the live
#      check-runs for that SHA, or with the wrong app id (RESEARCH P-07 —
#      a context GitHub has never seen becomes a permanently-pending
#      required check)
#
# NEVER read the CLASSIC protection endpoint (`branches/main/` + `protection`)
# as evidence of anything — it 404s on this repo BY DESIGN because classic
# protection is unused (STATE.md 14-02 records that 404 as a false
# negative). The authoritative read-back path is always `rules/branches/main`.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'USAGE'
set-required-checks.sh — read-modify-write helper for the branch ruleset
required_status_checks + pull_request rules.

Usage:
  bash scripts/set-required-checks.sh [flags]

Flags:
  --repo OWNER/REPO           Target repository slug.
                               Default: OttawaCloudConsulting/security-platform
  --ruleset ID                Ruleset id to read/modify. Default: 14243983
  --input FILE                Read a captured ruleset JSON from FILE instead
                               of calling `gh api` GET. Makes the dry run
                               reproducible offline and testable.
  --out FILE                  Write the merged document to FILE.
                               Default: /tmp/set-required-checks-out.json
  --verify-sha SHA            Preflight: confirm all five contexts appear in
                               `commits/SHA/check-runs` with app.id 15368.
                               MANDATORY when --apply is passed.
  --apply                     Perform the live PUT. Requires --verify-sha and
                               --yes-i-understand-lockout. Without --apply
                               this script never writes to GitHub.
  --yes-i-understand-lockout  Explicit acknowledgement required alongside
                               --apply (see the lockout warning below).
  -h, --help                  Print this usage and exit 0 without contacting
                               GitHub.

Exit codes: see the header comment in this file for the full table
(0 success, 1 generic failure, 2 missing rules key, 3 dropped rule type,
4 --apply without --verify-sha, 5 --apply without lockout ack,
6 --verify-sha context mismatch).

This script never chmods itself executable. Invoke it with `bash`.
USAGE
}

REPO="OttawaCloudConsulting/security-platform"
RULESET_ID="14243983"
INPUT_FILE=""
OUT_FILE="/tmp/set-required-checks-out.json"
VERIFY_SHA=""
APPLY="false"
LOCKOUT_ACK="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --ruleset) RULESET_ID="$2"; shift 2 ;;
    --input) INPUT_FILE="$2"; shift 2 ;;
    --out) OUT_FILE="$2"; shift 2 ;;
    --verify-sha) VERIFY_SHA="$2"; shift 2 ;;
    --apply) APPLY="true"; shift 1 ;;
    --yes-i-understand-lockout) LOCKOUT_ACK="true"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# --apply guards, checked BEFORE any network call.
if [ "$APPLY" = "true" ] && [ -z "$VERIFY_SHA" ]; then
  echo "REFUSED: --apply requires --verify-sha (RESEARCH P-07: an unverified" >&2
  echo "context becomes a permanently-pending required check). No network call made." >&2
  exit 4
fi
if [ "$APPLY" = "true" ] && [ "$LOCKOUT_ACK" != "true" ]; then
  cat >&2 <<'LOCKOUT'
REFUSED: --apply requires --yes-i-understand-lockout.

SELF-LOCKOUT WARNING for OttawaCloudConsulting/security-platform specifically:
  - fixtures/ exists to make every scanner fire. Under gate_mode: blocking,
    all five required checks go RED on every PR, including a PR that reverts
    this very change.
  - The live ruleset reports bypass_actors: [] and
    current_user_can_bypass: "never" — rulesets do NOT auto-exempt repo
    admins. There is no bypass path once this is applied under blocking mode.
  - If you want this on THIS repo's main, add a bypass actor (repo admin
    role) in the GitHub UI FIRST (Settings > Rules > Rulesets > Default >
    Bypass list), then re-run with --apply.
No network call made.
LOCKOUT
  exit 5
fi

# ── 1. READ ──────────────────────────────────────────────────────────────
if [ -n "$INPUT_FILE" ]; then
  BEFORE_FILE="$INPUT_FILE"
else
  BEFORE_FILE="$(mktemp)"
  gh api "repos/${REPO}/rulesets/${RULESET_ID}" > "$BEFORE_FILE"
fi

# ── 2. VERIFY-SHA preflight (mandatory under --apply; optional otherwise) ──
if [ -n "$VERIFY_SHA" ]; then
  echo "verify-sha: checking five contexts appear live at ${VERIFY_SHA} (app.id 15368)"
  LIVE_NAMES="$(gh api "repos/${REPO}/commits/${VERIFY_SHA}/check-runs" \
    --jq '.check_runs[] | select(.app.id == 15368) | .name')"
  MISSING="false"
  while IFS= read -r ctx; do
    if ! printf '%s\n' "$LIVE_NAMES" | grep -qxF "$ctx"; then
      echo "MISSING at ${VERIFY_SHA}: ${ctx}" >&2
      MISSING="true"
    fi
  done <<'CONTEXTS'
security / SAST — Semgrep CE
security / IaC — Checkov
security / SCA — Trivy Filesystem
security / Container — Trivy Image
security / Secrets — Gitleaks
CONTEXTS
  if [ "$MISSING" = "true" ]; then
    echo "verify-sha FAILED — a context missing here becomes a permanently-pending" >&2
    echo "required check (RESEARCH P-07). Refusing to proceed." >&2
    exit 6
  fi
  echo "verify-sha OK — all five contexts found live with app id 15368"
fi

# ── 3. MODIFY (quoted heredoc — the em dash and $ fragments must never be ──
#      shell-expanded before python sees them) ────────────────────────────
python3 - "$BEFORE_FILE" "$OUT_FILE" <<'PY'
import json
import sys

before_path, out_path = sys.argv[1], sys.argv[2]
doc = json.load(open(before_path, encoding="utf-8"))

if "rules" not in doc:
    print("ABORT: fetched document has no 'rules' key — a missing key and an "
          "empty array mean different things; refusing to treat this as safe "
          "to build on.", file=sys.stderr)
    sys.exit(2)

CONTEXTS = [
    "security / SAST — Semgrep CE",
    "security / IaC — Checkov",
    "security / SCA — Trivy Filesystem",
    "security / Container — Trivy Image",
    "security / Secrets — Gitleaks",
]
INTEGRATION_ID = 15368

before_types = [r["type"] for r in doc["rules"]]
print("BEFORE rule types:", before_types)

kept = [r for r in doc["rules"] if r["type"] not in ("required_status_checks", "pull_request")]
kept.append({
    "type": "required_status_checks",
    "parameters": {
        "do_not_enforce_on_create": False,
        "strict_required_status_checks_policy": False,
        "required_status_checks": [
            {"context": c, "integration_id": INTEGRATION_ID} for c in CONTEXTS
        ],
    },
})
kept.append({
    "type": "pull_request",
    "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": False,
        "require_code_owner_review": False,
        "require_last_push_approval": False,
        "required_review_thread_resolution": False,
    },
})

body = {
    "name": doc["name"],
    "target": doc["target"],
    "enforcement": doc["enforcement"],
    "conditions": doc["conditions"],
    "bypass_actors": doc.get("bypass_actors", []),
    "rules": kept,
}

after_types = [r["type"] for r in body["rules"]]
print("AFTER  rule types:", after_types)

dropped = set(before_types) - set(after_types)
if dropped:
    print("ABORT: merged document would DROP pre-existing rule type(s): %r — "
          "this is exactly the P-05 regression; refusing to write the output "
          "file." % sorted(dropped), file=sys.stderr)
    sys.exit(3)

json.dump(body, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("Merged document written to", out_path)
print("Every pre-existing rule type preserved; %d contexts added, each pinned "
      "to integration_id %d." % (len(CONTEXTS), INTEGRATION_ID))
PY
rc=$?
if [ -z "$INPUT_FILE" ]; then
  rm -f "$BEFORE_FILE"
fi
if [ $rc -ne 0 ]; then
  exit $rc
fi

if [ "$APPLY" != "true" ]; then
  echo "DRY RUN complete. No write made to GitHub. Merged document: ${OUT_FILE}"
  exit 0
fi

# ── 4. WRITE — only reached when --apply, --verify-sha and the lockout ────
#      acknowledgement have all been satisfied. --input is not passed to the ──
#      PUT itself, only the just-built merged document is.
echo "APPLYING — PUT repos/${REPO}/rulesets/${RULESET_ID} from ${OUT_FILE}"
gh api --method PUT "repos/${REPO}/rulesets/${RULESET_ID}" --input "$OUT_FILE"

# ── 5. VERIFY — the authoritative read-back. NEVER the classic protection ──
#      endpoint (404s on this repo by design; STATE.md 14-02).
echo "Read-back: repos/${REPO}/rules/branches/main rule types:"
gh api "repos/${REPO}/rules/branches/main" --jq '.[].type'
echo "Read-back: required contexts on ruleset ${RULESET_ID}:"
gh api "repos/${REPO}/rulesets/${RULESET_ID}" \
  --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[] | .context'
