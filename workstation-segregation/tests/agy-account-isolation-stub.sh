#!/bin/bash
# Offline operator responses and a fake AGY; never invokes real authentication.
set -Eeuo pipefail
kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /private/tmp/wsk-agy-account.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
export FIXTURE="$fixture"
cat > "$fixture/agy" <<'STUB'
#!/bin/bash
set -eu
for name in $(compgen -e); do
  case "$name" in GOOGLE_*|GEMINI_*|GCLOUD_*|CLOUDSDK_*|AGY_*|ANTIGRAVITY_*|VERTEX_*|WORKSTATION_*|DIRENV_*|XDG_*|BASH_ENV|ENV) exit 91 ;; esac
done
[ -z "$(ls -A .)" ]
[ "$TMPDIR" = "${PWD%/workspace}/tmp" ]
if [ "${1:-}" = --version ]; then printf '1.3.4\n'; exit 0; fi
[ "$#" = 0 ]
case "$PWD" in */ordinary/workspace) [ "$HOME" = "$FIXTURE/ordinary" ] ;; *) [ "$HOME" = "${PWD%/workspace}/home" ] ;; esac
printf '%s\n' "$HOME" >> "$FIXTURE/launches"
# Synthetic raw app data and terminal output must not enter reports.
printf 'SYNTHETIC_SECRET\n' > "$HOME/private-state"
printf 'SYNTHETIC_SECRET\n'
if [ -f "$FIXTURE/interrupt" ]; then rm "$FIXTURE/interrupt"; kill -TERM "$PPID"; fi
if [ -f "$FIXTURE/startup-error" ]; then exit 42; fi
STUB
chmod 755 "$fixture/agy"
mkdir "$fixture/ordinary"
export HOME="$fixture/ordinary" AGY_ACCOUNT_STUB_TEST=1
export GOOGLE_API_KEY=SYNTHETIC_SECRET GEMINI_CLI_HOME=outside ANTIGRAVITY_APP_DATA_DIR=outside
export XDG_CONFIG_HOME=outside WORKSTATION_CLIENT_DIR=outside DIRENV_DIR=outside
harness() { /bin/bash "$kit/tests/agy-account-isolation.sh" --binary "$fixture/agy" "$@"; }
responses() {
  printf 'run\nexpected\nrun\nsignin\nrun\nexpected\nrun\nexpected\nrun\nsignin\nrun\nexpected\n'
  if [ "${1:-one}" = two ]; then printf 'yes\nrun\nexpected\nrun\nexpected\nrun\nexpected\nrun\nexpected\nrun\nexpected\n'; fi
  printf 'inside\n'
}
responses | harness --state-dir "$fixture/one" > "$fixture/terminal" 2>&1
grep -q 'Overall: pending' "$fixture/one/reports/"*
[ -f "$fixture/one/A/home/private-state" ] && [ -f "$fixture/one/B/home/private-state" ]
[ "$HOME" = "$fixture/ordinary" ] && [ "$GOOGLE_API_KEY" = SYNTHETIC_SECRET ]
# Reopen the same root across processes (no fresh sign-in/authentication steps).
printf 'run\nexpected\nrun\nexpected\nrun\nexpected\ninside\n' | harness --state-dir "$fixture/one" > /dev/null 2>&1
[ "$(find "$fixture/one/reports" -type f | wc -l | tr -d ' ')" = 2 ]
responses two | harness --state-dir "$fixture/two" --accounts two > /dev/null 2>&1
grep -q 'Overall: pass' "$fixture/two/reports/"*
# A second process can recheck both persisted accounts, but cannot accept a reused root.
printf 'run\nexpected\nrun\nexpected\nrun\nexpected\nyes\nrun\nexpected\nrun\nexpected\nrun\nexpected\nrun\nexpected\ninside\n' | harness --state-dir "$fixture/two" --accounts two > /dev/null 2>&1
[ "$(find "$fixture/two/reports" -type f | wc -l | tr -d ' ')" = 2 ]
# Installed executable discovery does not require an explicit binary path.
printf 'skip\n' | PATH="$fixture:$PATH" /bin/bash "$kit/tests/agy-account-isolation.sh" --state-dir "$fixture/from-path" > /dev/null 2>&1
grep -q "Binary: $fixture/agy" "$fixture/from-path/reports/"*
# Reuse, ordinary-account change and startup errors must never pass.
if printf 'run\nexpected\nrun\nexpected\n' | harness --state-dir "$fixture/reuse" > /dev/null 2>&1; then exit 1; fi
grep -q 'Overall: fail' "$fixture/reuse/reports/"*
if printf 'run\nother\n' | harness --state-dir "$fixture/changed" > /dev/null 2>&1; then exit 1; fi
[ "$(wc -l < "$fixture/changed/reports/"* | tr -d ' ')" -gt 0 ]
touch "$fixture/startup-error"
printf 'run\nexpected\n' | harness --state-dir "$fixture/error" > /dev/null 2>&1
rm "$fixture/startup-error"
grep -q 'Overall: pending' "$fixture/error/reports/"*
printf 'skip\n' | harness --state-dir "$fixture/skipped" > /dev/null 2>&1
grep -q 'Overall: pending' "$fixture/skipped/reports/"*
if harness --state-dir "$fixture/eof" < /dev/null > /dev/null 2>&1; then exit 1; fi
grep -q 'Overall: pending' "$fixture/eof/reports/"*
touch "$fixture/interrupt"
status=0
printf 'run\nexpected\n' | harness --state-dir "$fixture/interrupted" > /dev/null 2>&1 || status=$?
[ "$status" = 143 ]
[ ! -d "$fixture/interrupted/.run-lock" ] && [ -f "$fixture/interrupted/.agy-account-harness" ]
printf 'skip\n' | harness --state-dir "$fixture/interrupted" > /dev/null 2>&1
mkdir "$fixture/unrelated"
ln -s "$fixture/unrelated" "$fixture/link"
for path in relative "$fixture/unrelated" "$fixture/link" "$fixture/link/child"; do
  if harness --state-dir "$path" < /dev/null > /dev/null 2>&1; then exit 1; fi
done
ln -s "$fixture/unrelated" "$fixture/one/A/home/link"
# A linked required directory, not merely a symlink stored by AGY, is rejected.
mv "$fixture/one/B/tmp" "$fixture/old-tmp"
ln -s "$fixture/old-tmp" "$fixture/one/B/tmp"
if harness --state-dir "$fixture/one" < /dev/null > /dev/null 2>&1; then exit 1; fi
if harness --state-dir "$fixture/bad-args" -- --prompt hi < /dev/null > /dev/null 2>&1; then exit 1; fi
python3 - "$fixture" <<'PY'
import pathlib, stat, sys
root = pathlib.Path(sys.argv[1])
for reports in root.glob('*/reports'):
    assert stat.S_IMODE(reports.stat().st_mode) == 0o700
    for report in reports.iterdir():
        assert stat.S_IMODE(report.stat().st_mode) == 0o600
        assert 'SYNTHETIC_SECRET' not in report.read_text()
for p in [root/'two', root/'two/A/home', root/'two/B/tmp']:
    assert stat.S_IMODE(p.stat().st_mode) == 0o700
PY
printf 'PASS: persistent harness, account gates, privacy, interruption recovery and invalid roots\n'
