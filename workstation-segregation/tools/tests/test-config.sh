#!/bin/bash
# Config: .env as data, --groups replaces env, implicit base, unknown groups, cycles, order.
. "$(dirname "$0")/helpers.sh"
new_fixture; set_latest_all
trap cleanup_fixture EXIT

# default selection is base only
run_engine --dry-run
assert_rc "$RC" 0 "default"
assert_not_contains "$OUT" "kubectl" "default selects only base"

# .env selection with injection lines that must not execute or print
cat > "$FX/project/.env" <<'ENV'
SECRET_TOKEN=supersecretvalue
$(touch INJECTED)
export TOOL_GROUPS= "github , go,github"
`touch INJECTED2`
ENV
run_engine --dry-run
assert_rc "$RC" 0 ".env"
assert_contains "$OUT" "gh " "env group github selected"
assert_contains "$OUT" "go " "env group go selected"
assert_not_contains "$OUT" "supersecretvalue" "values not printed"
assert_no_file "$FX/project/INJECTED"
assert_no_file "$FX/project/INJECTED2"

# --groups replaces env
run_engine --dry-run --groups database-redis
assert_not_contains "$OUT" "  gh " "groups replaces env"
assert_contains "$OUT" "redis-cli" "cli group"

# unknown group -> usage error 2
run_engine --dry-run --groups nonsense
assert_rc "$RC" 2 "unknown group"
assert_contains "$OUT" "unknown group: nonsense" "unknown group message"

# unreadable explicit env file -> 1; missing default -> fine
run_engine --dry-run --env-file "$FX/nope.env"
assert_rc "$RC" 1 "unreadable explicit env"

# usage errors
run_engine --bogus
assert_rc "$RC" 2 "bogus flag"
run_engine --groups
assert_rc "$RC" 2 "missing value"

# dependencies expand: aws pulls in containers (docker-cli) before aws tools
run_engine --dry-run --groups aws
assert_rc "$RC" 0 "aws"
cli_line="$(echo "$OUT" | grep -n '^docker-cli ' | cut -d: -f1)"
sam_line="$(echo "$OUT" | grep -n '^aws-sam ' | cut -d: -f1)"
if [ -n "$cli_line" ] && [ -n "$sam_line" ] && [ "$cli_line" -lt "$sam_line" ]; then ok; else fail "docker-cli must precede aws-sam"; fi
assert_not_contains "$OUT" "kubectl " "aws does not select kubernetes"

# group cycle -> usage error
mkdir -p "$FX/catalog"; cp "$TOOLS_DIR"/scripts/common/catalog/*.tsv "$FX/catalog/"
printf 'ansible\tgo\ngo\tansible\n' > "$FX/catalog/cyc.tmp"
awk -F'\t' 'BEGIN{OFS="\t"} $1=="ansible"{$2="go"} $1=="go"{$2="ansible"} {print}' "$FX/catalog/groups.tsv" > "$FX/catalog/g2" && mv "$FX/catalog/g2" "$FX/catalog/groups.tsv"
WST_CATALOG_DIR="$FX/catalog" run_engine --dry-run --groups go
assert_rc "$RC" 2 "group cycle"
assert_contains "$OUT" "cycle" "cycle message"
finish
