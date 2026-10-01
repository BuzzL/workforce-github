#!/usr/bin/env bash
# Lists the Terraform directories, one per line: `roots` (live/**),
# `modules` (modules/**) or `all`. A directory counts when it directly holds a *.tf or
# *.tf.json file. `tests/` and `.terraform/` directories are skipped: they hold test
# fixtures and provider caches, not stacks.
set -euo pipefail
cd "$(dirname "$0")/.."

dirs() {
  for base in "$@"; do
    [ -d "$base" ] || continue
    find "$base" \( -name .terraform -o -name tests \) -prune -o \
      \( -name '*.tf' -o -name '*.tf.json' \) -print |
      while read -r f; do dirname "$f"; done
  done | sort -u
}

# Every directory with Terraform must be under live/ or modules/: anywhere else the gates
# (validate, lint, test, versions, dependabot) would silently skip it.
stray=$(find . \( -name .terraform -o -name .git -o -name live -o -name modules \) -prune -o \
  \( -name '*.tf' -o -name '*.tf.json' \) -print | sort)
if [ -n "$stray" ]; then
  echo "Terraform outside live/ and modules/ is not checked by any gate:" >&2
  echo "$stray" >&2
  exit 1
fi

case "${1:-all}" in
  roots)   dirs live ;;
  modules) dirs modules ;;
  all)     dirs live modules ;;
  *)       echo "usage: $0 [roots|modules|all]" >&2; exit 2 ;;
esac
