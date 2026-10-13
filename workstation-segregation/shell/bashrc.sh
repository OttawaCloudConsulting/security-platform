# workstation-segregation interactive shell integration (bash 3.2+).
# Sourced from ~/.bashrc by the managed block written by deploy.sh.
# Needs WORKSTATION_SEGREGATION_ROOT and WORKSTATION_SEGREGATION_BIN (exported by that block).

# Guard against double sourcing (e.g. ~/.profile and ~/.bash_profile both
# loading ~/.bashrc). Plain variable on purpose: child shells re-initialise.
[ -n "${_WSK_LOADED:-}" ] && return 0
_WSK_LOADED=1

if [ -n "${WORKSTATION_SEGREGATION_BIN:-}" ]; then
  case ":$PATH:" in *":$WORKSTATION_SEGREGATION_BIN:"*) ;; *) export PATH="$WORKSTATION_SEGREGATION_BIN:$PATH" ;; esac
fi

case $- in *i*) ;; *) return 0 ;; esac

export AWS_PAGER=""

# shellcheck source=/dev/null
[ -r "$WORKSTATION_SEGREGATION_ROOT/shell/aliases.sh" ] && . "$WORKSTATION_SEGREGATION_ROOT/shell/aliases.sh"

# Export HISTFILE so direnv restores it (instead of unsetting it) when
# leaving a client directory whose .envrc sets its own HISTFILE.
export HISTFILE="${HISTFILE:-$HOME/.bash_history}"

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"

  # Bash only reads HISTFILE at startup and writes it at exit. When direnv
  # changes HISTFILE, save this session's commands to the old file and load
  # the new one, so each client directory keeps its own history.
  _workstation_histfile="$HISTFILE"
  _workstation_history_sync() {
    if [[ "$HISTFILE" != "$_workstation_histfile" ]]; then
      history -a "$_workstation_histfile"
      history -c
      history -r "$HISTFILE"
      _workstation_histfile="$HISTFILE"
    fi
  }
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_workstation_history_sync"

  # Client shell fragments. When direnv sets WORKSTATION_CLIENT_DIR, source
  # <client>/.workstation/bash/*.sh. When it changes or clears, remove the
  # functions and aliases those fragments added. Fragments should only add new
  # functions and aliases; other shell changes are not undone on leave.
  _workstation_client_loaded=""
  _workstation_client_functions=""
  _workstation_client_aliases=""
  _workstation_client_sync() {
    [[ "${WORKSTATION_CLIENT_DIR:-}" == "$_workstation_client_loaded" ]] && return
    local name fragment before_functions before_aliases
    for name in $_workstation_client_functions; do unset -f "$name"; done
    for name in $_workstation_client_aliases; do unalias "$name" 2>/dev/null; done
    _workstation_client_functions=""
    _workstation_client_aliases=""
    _workstation_client_loaded="${WORKSTATION_CLIENT_DIR:-}"
    [[ -n "$_workstation_client_loaded" ]] || return 0

    before_functions=$'\n'"$(compgen -A function)"$'\n'
    before_aliases=$'\n'"$(compgen -a)"$'\n'
    for fragment in "$_workstation_client_loaded"/.workstation/bash/*.sh; do
      if [[ -f "$fragment" && -r "$fragment" ]]; then
        # shellcheck source=/dev/null
        . "$fragment"
      fi
    done
    for name in $(compgen -A function); do
      [[ "$before_functions" == *$'\n'"$name"$'\n'* ]] || _workstation_client_functions+="$name "
    done
    for name in $(compgen -a); do
      [[ "$before_aliases" == *$'\n'"$name"$'\n'* ]] || _workstation_client_aliases+="$name "
    done
  }
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_workstation_client_sync"
fi

# Starship prompt, using the kit's config (shows the active client) unless the
# user already exports STARSHIP_CONFIG.
if command -v starship >/dev/null 2>&1; then
  : "${STARSHIP_CONFIG:=$WORKSTATION_SEGREGATION_ROOT/templates/starship.toml}"
  export STARSHIP_CONFIG
  eval "$(starship init bash)"
fi
