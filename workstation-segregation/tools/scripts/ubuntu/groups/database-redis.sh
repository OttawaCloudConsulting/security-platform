#!/bin/bash
# database-redis group on ubuntu: client only (see misc-shared.sh).
# shellcheck source=../../common/misc-shared.sh
. "$WST_ROOT/scripts/common/misc-shared.sh"

apt_client_tool redis-cli redis-tools redis-cli 'redis-cli --version'
