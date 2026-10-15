#!/bin/bash
# database-mysql group on macos: client only (see misc-shared.sh).
# shellcheck source=../../common/misc-shared.sh
. "$WST_ROOT/scripts/common/misc-shared.sh"

brew_keg_tool mysql-client mysql-client mysql
