#!/bin/bash
# database-postgres group on ubuntu: client only (see misc-shared.sh).
# shellcheck source=../../common/misc-shared.sh
. "$WST_ROOT/scripts/common/misc-shared.sh"

apt_client_tool psql postgresql-client psql 'psql --version'
