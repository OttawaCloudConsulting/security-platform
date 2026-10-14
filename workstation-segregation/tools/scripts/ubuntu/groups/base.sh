#!/bin/bash
# base group on Ubuntu: apt packages plus the shared release/AI tools.
# shellcheck source=../../common/base-shared.sh
. "$WST_ROOT/scripts/common/base-shared.sh"

apt_tool ca-certificates ca-certificates - 'test -s /etc/ssl/certs/ca-certificates.crt'
apt_tool curl curl curl 'curl --version'
apt_tool wget wget wget 'wget --version'
apt_tool zip zip zip 'zip -v'
apt_tool unzip unzip unzip 'unzip -v'
apt_tool tar tar tar 'tar --version'
apt_tool gzip gzip gzip 'gzip --version'
apt_tool git git git 'git --version'
apt_tool openssh-client openssh-client ssh 'ssh -V'
apt_tool build-tools build-essential make 'make --version'
apt_tool tree tree tree 'tree --version'
apt_tool ripgrep ripgrep rg 'rg --version'
apt_tool fzf fzf fzf 'fzf --version'
apt_tool tmux tmux tmux 'tmux -V'
apt_tool rsync rsync rsync 'rsync --version'
apt_tool dnsutils dnsutils dig 'dig -v'
apt_tool nc netcat-openbsd nc 'command -v nc'
apt_tool python3 python3 python3 'python3 --version'
apt_tool pip3 python3-pip pip3 'pip3 --version'
