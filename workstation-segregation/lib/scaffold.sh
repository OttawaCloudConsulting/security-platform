#!/bin/bash
# Per-client segregation scaffolding. Requires lib/common.sh and load_config.
# Everything is create-if-missing: existing client files are never overwritten.

CLIENT_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
MARKER_REL=".workstation/.segregation-managed"

# A directory that already carries segregation (adopted at deploy time).
is_segregated() { # is_segregated <dir>
  [ -d "$1/.workstation" ] && return 0
  [ -f "$1/.envrc" ] && grep -q 'WORKSTATION_CLIENT' "$1/.envrc" 2>/dev/null && return 0
  return 1
}

_resolve_gh() {
  local g
  g="$(PATH="$BIN_DIR:$PATH" command -v gh 2>/dev/null || true)"
  printf '%s\n' "${g:-$BIN_DIR/gh}"
}

# _install_tpl <template> <dest relative to client> <mode>; returns 1 if it existed.
_install_tpl() {
  local src="$KIT_ROOT/templates/client/$1" dest="$R_DIR/$2" mode="$3"
  [ -e "$dest" ] && return 1
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: create $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  render_template "$src" > "$dest"
  chmod "$mode" "$dest"
  log "created $dest"
  return 0
}

_mkdir_private() { # _mkdir_private <path>: mode 700, only when newly created
  [ -d "$1" ] && return 0
  run mkdir -p "$1"
  run chmod 700 "$1"
}

# Private global Git defaults, followed by exactly this client's config.
_install_agy_gitconfig() {
  local dest="$R_DIR/.workstation/agy/gitconfig" key value
  [ ! -e "$dest" ] && [ ! -L "$dest" ] || return 0
  if [ "$DRY_RUN" = 1 ]; then log "DRY-RUN: create $dest"; return 0; fi
  (umask 077; : > "$dest")
  while IFS='=' read -r key value; do
    case "$key" in ''|'#'*) continue ;; esac
    git config --file "$dest" "$key" "$value"
  done < "$KIT_ROOT/templates/git-global.conf"
  git config --file "$dest" include.path "$R_DIR/.workstation/git/config"
  chmod 600 "$dest"
}

# adopt: dir is already segregated; add only inert config files (no sourced shell
# fragments that would change SSH or Codex behaviour).
scaffold_client() { # scaffold_client <abs dir> [adopt]
  local dir="$1" mode="${2:-new}" name sub envrc_created=0
  name="$(basename "$dir")"
  if ! printf '%s' "$name" | grep -Eq "$CLIENT_NAME_RE"; then
    warn "skipping '$name': client names must match $CLIENT_NAME_RE"
    return 1
  fi

  R_CLIENT="$name"
  R_CLIENT_UC="$(printf '%s' "$name" | tr 'a-z.-' 'A-Z__')"
  R_DIR="$dir"
  R_GH="$(_resolve_gh)"
  if [ "$ENABLE_AGENT_CLI_ISOLATION" = 1 ]; then R_AGENT_PREFIX=""; else R_AGENT_PREFIX="# "; fi

  log "scaffolding client '$name' ($dir)${mode:+ [$mode]}"
  [ -d "$dir/.workstation" ] || run mkdir -p "$dir/.workstation"
  for sub in git bash; do
    [ -d "$dir/.workstation/$sub" ] || run mkdir -p "$dir/.workstation/$sub"
  done
  for sub in gh docker helm helm/config helm/cache terraform npm python age ssh claude codex openai; do
    _mkdir_private "$dir/.workstation/$sub"
  done
  # Inert private state may be prepared on adoption; never add a sourced wrapper.
  if [ "$ENABLE_AGENT_CLI_ISOLATION" = 1 ] && [ "${ENABLE_AGY_CLI_ISOLATION:-0}" = 1 ]; then
    for sub in agy agy/home agy/tmp; do _mkdir_private "$dir/.workstation/$sub"; done
    _install_agy_gitconfig
  fi
  _mkdir_private "$dir/.aws"
  _mkdir_private "$dir/.kube"

  _install_tpl envrc                   .envrc                               644 && envrc_created=1 || true
  _install_tpl git-config              .workstation/git/config              644 || true
  _install_tpl ssh-config              .workstation/ssh/config              600 || true
  if [ "$mode" != adopt ]; then
    _install_tpl ssh-fragment.sh       .workstation/bash/ssh.sh             644 || true
    if [ "$ENABLE_AGENT_CLI_ISOLATION" = 1 ]; then
      _install_tpl codex-fragment.sh   .workstation/bash/codex.sh           644 || true
      if [ "${ENABLE_AGY_CLI_ISOLATION:-0}" = 1 ]; then
        _install_tpl agy-fragment.sh   .workstation/bash/agy.sh             644 || true
      fi
    fi
  fi
  _install_tpl docker-config.json      .workstation/docker/config.json      600 || true
  _install_tpl terraformrc             .workstation/terraform/terraformrc   600 || true
  _install_tpl npmrc                   .workstation/npm/npmrc               600 || true
  _install_tpl pip.conf                .workstation/python/pip.conf         600 || true
  _install_tpl uv.toml                 .workstation/python/uv.toml          600 || true
  _install_tpl age-keys.txt            .workstation/age/keys.txt            600 || true
  _install_tpl claude-settings.json    .workstation/claude/settings.json    600 || true
  _install_tpl codex-config.toml       .workstation/codex/config.toml       600 || true
  _install_tpl openai-env              .workstation/openai/env              600 || true
  _install_tpl aws-config              .aws/config                          600 || true
  _install_tpl kube-config             .kube/config                         600 || true

  if [ ! -e "$dir/$MARKER_REL" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      log "DRY-RUN: create $dir/$MARKER_REL"
    else
      date '+managed by workstation-segregation since %Y-%m-%dT%H:%M:%S' > "$dir/$MARKER_REL"
    fi
  fi

  # Only approve an .envrc this kit generated; never auto-trust a pre-existing one.
  if [ "$envrc_created" = 1 ] && [ "$DRY_RUN" != 1 ]; then
    if PATH="$BIN_DIR:$PATH" command -v direnv >/dev/null 2>&1; then
      PATH="$BIN_DIR:$PATH" direnv allow "$dir" >/dev/null 2>&1 \
        && log "direnv allow: $dir" \
        || warn "direnv allow failed for $dir (run it manually)"
    else
      warn "direnv not found; run 'direnv allow' in $dir after installing it"
    fi
  fi
  return 0
}

# Regenerate the include file that wires each client's git config in.
# Loaded from ~/.gitconfig via a managed [include] kept last (see global.sh).
regen_gitconfig_clients() {
  local out="$KIT_CONFIG_DIR/gitconfig-clients" d name kw tmp real
  if [ "$KIT_OS" = darwin ]; then kw="gitdir/i"; else kw="gitdir"; fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/wsk-gitc.XXXXXX")"
  {
    printf '# Generated by workstation-segregation; do not edit (regenerated by the watcher).\n'
    for d in "$CLIENT_ROOT"/*/; do
      d="${d%/}"
      [ -d "$d" ] && [ ! -L "$d" ] || continue
      name="$(basename "$d")"
      is_excluded "$name" && continue
      [ -f "$d/.workstation/git/config" ] || continue
      printf '[includeIf "%s:%s/"]\n\tpath = %s/.workstation/git/config\n' "$kw" "$d" "$d"
      # git matches gitdir against the physical path; add it when the root is reached via a symlink.
      real="$(cd -P "$d" 2>/dev/null && pwd || true)"
      if [ -n "$real" ] && [ "$real" != "$d" ]; then
        printf '[includeIf "%s:%s/"]\n\tpath = %s/.workstation/git/config\n' "$kw" "$real" "$d"
      fi
    done
  } > "$tmp"
  write_file_if_changed "$out" 644 < "$tmp"
  rm -f "$tmp"
}

# One-line status of what the user still has to fill in.
client_placeholder_status() { # client_placeholder_status <dir>
  local d="$1" notes=""
  git config --file "$d/.workstation/git/config" user.email >/dev/null 2>&1 \
    || notes="git identity unset"
  if [ ! -s "$d/.workstation/gh/hosts.yml" ]; then
    notes="${notes:+$notes, }gh not logged in"
  fi
  printf '%s\n' "${notes:-ok}"
}
