#!/bin/bash
# database-redis group on macos: client only (see misc-shared.sh).
# shellcheck source=../../common/misc-shared.sh
. "$WST_ROOT/scripts/common/misc-shared.sh"

brew_tool redis-cli redis redis-cli 'redis-cli --version'
