#!/bin/bash
set -euo pipefail

# Pre-commit hook: lint only staged markdown files.
# Auto-fixes are re-staged so they are included in the commit.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

files=$(git diff --cached --name-only --diff-filter=ACM -- '*.md' | grep -v '^\.' || true)

if [[ -z "$files" ]]; then
  echo "==> No staged markdown files, skipping lint"
  exit 0
fi

for f in $files; do
  bash "${REPO_ROOT}/cicd/lint-markdown.sh" "$f"
  git add "$f"
done
