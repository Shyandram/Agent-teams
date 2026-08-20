#!/usr/bin/env bash
# Run every check. Exit non-zero if any fails.
#   bash test/all.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
fail=0
for t in "$here"/*.sh; do
  case "$(basename "$t")" in all.sh) continue ;; esac
  echo "═══ $(basename "$t") ═══"
  bash "$t" || fail=1
  echo
done
[ "$fail" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit "$fail"
