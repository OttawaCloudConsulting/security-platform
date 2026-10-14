# Workstation Tool Installer: Developer Guide

## Layout

```text
tools/
  setup-workstation.sh            orchestrator, Bash 3.2-safe
  scripts/
    orchestrator/{common,macos,ubuntu}.sh   3.2-safe; common.sh is also used by the engine
    common/                       Bash 5 engine
      main.sh          entry; flow below
      common.sh        handler-name helpers
      catalog.sh       loads catalog/*.tsv into associative arrays
      configuration.sh args and .env parsing
      groups.sh        group + tool resolution, topological order
      versions.sh      gh_latest_tag, ver_cmp, ver_matches
      download.sh      sha256/sha512 verification, DL_STATUS
      state.sh         requested/installed JSON via $WST_JQ
      plan.sh          handler loading, discovery, probe, classify, removal rules
      engine.sh        execution, validation, records, report
      handlers.sh      generators: release_tool apt_tool brew_tool npm_tool uv_tool os_tool
      base-shared.sh   base tools identical on both OSes
      catalog/{groups,tools}.tsv
    {ubuntu,macos}/groups/<group>.sh        per-OS handlers
  tests/
```

## Bash 3.2 rule

`setup-workstation.sh`, `scripts/orchestrator/*`, `versions.sh` and `download.sh` run under macOS Bash 3.2: no `declare -A`, `mapfile`, `${v,,}`, `[[ -v`, `|&`, `&>>`, `local -n`, `globstar`. `test-lint.sh` greps for these. Everything else is Bash 5; the orchestrator `exec`s `main.sh` with the Bash 5 binary.

## Control flow

`setup-workstation.sh`: locate root, pre-scan `--dry-run/--yes`, detect OS, privilege (`SUDO`), **lock** (not under dry-run), OS prerequisites, login shell (exit 75 on change), nvm/Node, bootstrap jq, `exec` main with `WST_ROOT WST_PROJECT_DIR WST_JQ WST_OS WST_ARCH WST_LOCK DRY_RUN ASSUME_YES WST_PREREQ_REPORT`.

`main.sh`: parse args, add `~/.local/bin` to PATH, adopt the lock (exec keeps the PID), load catalog, resolve groups and tools, load/validate/apply the requested file, static removal rules 1-5, persist requested file, load handlers (resolved groups plus home group of every removal-flagged tool), **discover all latest**, probe and classify, ownership rule 6, print plan, stop on dry-run, confirm removals, run removals (reverse topological), run installs (topological), report. Exit non-zero if any tool failed or was blocked.

## Catalog

`tools.tsv` columns: `id display groups depends relation removal checksum`. Empty fields are `-` (tab IFS collapses empties). `display` equals the bullet in `TOOL-GROUPS-CONSOLIDATED.md`; `test-catalog-sync.sh` enforces group membership, group dependencies and dependency-table tools. Groups `-` marks an implicit tool (`dnsutils`). `relation`: `bundled` (follows provider unless the OS script defines its own `latest`), `provider`, `plugin`, `runtime`. `removal`: `never|base|normal`. `checksum`: `yes|no|n/a`; `yes` tools must report `integrity=verified`.

## Handler contract

Defined in the tool's first group script (`tool_<id with _>_<suffix>`):

| Function | Purpose |
|---|---|
| `latest` | print the newest installable version; non-zero fails the tool |
| `probe` | lines `version<TAB>path<TAB>source<TAB>package_id` (`-` = empty), active-on-PATH first |
| `install VER RESULT_FILE` | install; append `integrity=<status>` to the result file; runs in a subshell with `TOOL_TMP` set |
| `remove` | uninstall and revert installer-made integration |
| `validate` | functional check |
| `source` (optional) | managed source label; a different active source is a `conflict` unless the version already matches |
| `kind` (optional) | `os` = platform-provided: probe/validate only, pins rejected, never owned |
| `pin_ok VER` (optional) | can this source honor the pin? |

Bundled tools without `latest` are "follow" tools: validated functionally, version and owner taken from the provider.

Adding a group: write `scripts/{ubuntu,macos}/groups/<group>.sh` using the generators in `handlers.sh`, add catalog rows if new, update the doc, run the tests.

## Ownership and removal

Only an install/upgrade by this installer sets `owner: workstation-tools`; reuse records `external`. Removal rules in order: unknown id, prerequisite (both rejected at file load), `never`, `base` without override, hard dependency of a remaining selected tool (or bundled command whose provider remains), ownership (record owner, status and path/package must match the probe). All rejections are collected and nothing changes.

## State and crash safety

JSON is read/written with `$WST_JQ`; writes use a temp file in the same directory then `mv`. The `mkdir` lock holds a pid file; stale when the pid is dead (EPERM counts alive) and the file is older than `WST_LOCK_STALE_SECS` (default 300). A failed update marks an existing record `failed`/`stale`; success is recorded right after validation.

## Tests

```bash
tools/tests/run.sh        # all; several minutes
/bin/bash tools/tests/test-removal.sh
```

Tests never touch the real HOME: `helpers.sh` builds a fixture HOME/XDG and drives the engine against `tests/fixtures/platform-fake`, whose handlers are controlled by files under `$FAKE_WORLD` (`latest/`, `installed/`, `failinstall/`, `badvalidate/`, `wrongversion/`, `integrity/`, `noremove/`, `kind/`) and log to `$WST_TRACE_FILE`. Crash tests set `WST_TEST_ABORT_AT` to `lock-mkdir`, `state-before-rename`, `state-after-rename` or `after-install`. `test-boundary.sh` runs the real orchestrator under Bash 3.2 with stubbed `brew sudo chsh apt-get curl ...`. Lint: `bash -n`, `shellcheck -s bash -x`, forbidden-construct grep.

Environment overrides used by tests: `WST_PLATFORM_DIR`, `WST_CATALOG_DIR`, `WST_BREW`, `WST_BOOTSTRAP_DIR`, `WST_OS`, `WST_ARCH`, `WST_BIN_DIR`, `WST_LOCK_STALE_SECS`, `WST_CLT_TIMEOUT`.

## Verifying on Ubuntu

```bash
docker run --rm -it -v "$PWD":/src:ro ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq curl ca-certificates && cd /tmp && bash /src/tools/setup-workstation.sh'
```

Runs as root (the `SUDO=""` path). Repeat to see reuse only.

## Sources worth knowing

jq: GitHub release + `sha256sum.txt`. yq: `checksums-bsd`. starship, uv: per-asset `.sha256`. uv tags have no `v`. direnv: no checksum published. Codex, Claude Code, Gemini CLI: npm through the nvm Node (Claude needs `--allow-scripts` on npm 12). gemini-notebook-mcp-cli: PyPI `notebooklm-mcp-cli` via `uv tool`. Antigravity: its manifest at `antigravity-cli-auto-updater-...run.app/manifests/<platform>.json` (version, url, sha512).
