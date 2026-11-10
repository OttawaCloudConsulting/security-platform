# workstation-segregation login-shell bootstrap (bash 3.2+). Sourced from ~/.bash_profile.
# Interactive behavior lives in shell/bashrc.sh via ~/.bashrc.
if [ -n "${WORKSTATION_SEGREGATION_BIN:-}" ]; then
  case ":$PATH:" in *":$WORKSTATION_SEGREGATION_BIN:"*) ;; *) export PATH="$WORKSTATION_SEGREGATION_BIN:$PATH" ;; esac
fi
if [ -r "$HOME/.bashrc" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.bashrc"
fi

# Refresh approved direnv environments for noninteractive login shells.
# Agent command shells do not draw a prompt, so the interactive PROMPT_COMMAND
# hook never runs and inherited client profiles can be missing or stale.
# direnv retains its own allow/deny checks; never source .envrc directly.
case $- in
  *i*) ;;
  *)
    if command -v direnv >/dev/null 2>&1; then
      eval "$(direnv export bash)"
    fi
    ;;
esac
