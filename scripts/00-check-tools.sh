#!/usr/bin/env bash
set -euo pipefail

tools=(docker kind kubectl helm)

for tool in "${tools[@]}"; do
  if command -v "${tool}" >/dev/null 2>&1; then
    printf "ok: %s -> %s\n" "${tool}" "$(command -v "${tool}")"
  else
    printf "missing: %s\n" "${tool}" >&2
    exit 1
  fi
done

echo
echo "Optional for AWS:"
for tool in aws terraform jq; do
  if command -v "${tool}" >/dev/null 2>&1; then
    printf "ok: %s -> %s\n" "${tool}" "$(command -v "${tool}")"
  else
    printf "optional missing: %s\n" "${tool}"
  fi
done
