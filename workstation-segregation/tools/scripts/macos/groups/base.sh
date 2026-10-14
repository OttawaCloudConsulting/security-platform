#!/bin/bash
# base group on macOS: Homebrew formulas, platform-provided tools and the
# shared release/AI tools.
# shellcheck source=../../common/base-shared.sh
. "$WST_ROOT/scripts/common/base-shared.sh"

brew_tool wget wget wget 'wget --version'
brew_tool tree tree tree 'tree --version'
brew_tool ripgrep ripgrep rg 'rg --version'
brew_tool fzf fzf fzf 'fzf --version'
brew_tool tmux tmux tmux 'tmux -V'
brew_tool python3 python3 python3 'python3 --version'   # pip3 is bundled and follows it

os_tool curl curl curl --version
os_tool zip zip zip -v
os_tool unzip unzip unzip -v
os_tool tar tar tar --version
os_tool gzip gzip gzip --version
os_tool git git git --version
os_tool openssh-client ssh ssh -V
os_tool build-tools make make --version
os_tool rsync rsync rsync --version
os_tool dnsutils dig dig -v
os_tool nc nc true
os_tool ca-certificates security true
tool_ca_certificates_probe() {
  [ -s /etc/ssl/cert.pem ] && printf '%s\t/etc/ssl/cert.pem\tos\t-\n' "$(sw_vers -productVersion 2>/dev/null || echo 0)"
  return 0
}
tool_ca_certificates_validate() { [ -s /etc/ssl/cert.pem ]; }
