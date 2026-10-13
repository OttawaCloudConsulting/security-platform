# {{CLIENT}} SSH: ssh, scp, and sftp use the client SSH config (sourced by the
# workstation-segregation client hook; removed when leaving the client directory).
ssh() { command ssh -F "$WORKSTATION_CLIENT_DIR/.workstation/ssh/config" "$@"; }
scp() { command scp -F "$WORKSTATION_CLIENT_DIR/.workstation/ssh/config" "$@"; }
sftp() { command sftp -F "$WORKSTATION_CLIENT_DIR/.workstation/ssh/config" "$@"; }
