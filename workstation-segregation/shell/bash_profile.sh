# workstation-segregation login-shell bootstrap (bash 3.2+). Sourced from ~/.bash_profile.
# Interactive behavior lives in shell/bashrc.sh via ~/.bashrc.
if [ -n "${WORKSTATION_SEGREGATION_BIN:-}" ]; then
  case ":$PATH:" in *":$WORKSTATION_SEGREGATION_BIN:"*) ;; *) export PATH="$WORKSTATION_SEGREGATION_BIN:$PATH" ;; esac
fi
if [ -r "$HOME/.bashrc" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.bashrc"
fi
