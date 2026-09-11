#!/usr/bin/env bash
set -euo pipefail

# detect-terraform.sh — report whether this repository contains Terraform
# files.
#
# Writes the discovered paths, one per line, to the list file named by $1
# (default: tf-files.txt) and logs on BOTH branches: "FOUND n ..." when .tf
# files exist, "SKIP: ..." when none do. Always exits 0 — "no Terraform in
# this repo" is a valid answer, not an error, and a non-zero exit here would
# fail the CI guard step on a clean skip.
#
# Pathspec: '*.tf'. Git's default (non-':(glob)') pathspec wildcards already
# cross '/', so a single leading '*' matches every depth. The two wrong forms,
# by analogy with the measured matrix in 16-RESEARCH Pitfall 9:
#   '.tf' / 'main.tf'        -> root-anchored, matches nothing in a subdirectory
#   '**/*.tf'                -> matches nested files ONLY, misses the repo root
# A missed manifest would produce a "SKIP:" line on a repo that really does
# have Terraform — a false pass that is invisible in the log.
#
# Invoked both by .github/workflows/security.yml (SCA-03) and by
# scripts/smoke-scans.sh, so the smoke gate tests the logic CI runs rather
# than a copy of it. Never set the executable bit: invoke as
# `bash scripts/detect-terraform.sh`, never `./scripts/detect-terraform.sh`.

LIST_FILE="${1:-tf-files.txt}"

count=0
files=""

while IFS= read -r path; do
  [ -n "$path" ] || continue
  count=$((count + 1))
  files="${files}${path}"$'\n'
done < <(git ls-files -- '*.tf')

if [ "$count" -eq 0 ]; then
  echo "SKIP: no .tf files found — Terraform pinning sub-scan not applicable to this repository"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "found=false" >>"$GITHUB_OUTPUT"
  fi
  exit 0
fi

printf '%s' "$files" >"$LIST_FILE"
echo "FOUND ${count} Terraform file(s):"
cat "$LIST_FILE"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "found=true" >>"$GITHUB_OUTPUT"
fi
exit 0
