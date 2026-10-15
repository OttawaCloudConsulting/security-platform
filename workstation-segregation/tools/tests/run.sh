#!/bin/bash
# Run every test-*.sh; stop at the first failing file.
here="$(cd "$(dirname "$0")" && pwd -P)"
rc=0
for t in "$here"/test-*.sh; do
  printf '== %s\n' "$(basename "$t")"
  /bin/bash "$t" || rc=1
done
[ "$rc" = 0 ] && echo "ALL PASSED" || echo "FAILURES"
exit "$rc"
