# shellcheck shell=bash
# {{CLIENT}} AGY: enabled only after two-account acceptance.
agy() { env -u BASH_ENV -u ENV /bin/bash "{{KIT}}/bin/agy-client.sh" "$@"; }
