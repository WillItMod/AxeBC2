#!/bin/sh
set -eu

reindex_flag="/data/.reindex-chainstate"
extra=""
if [ -f "${reindex_flag}" ]; then
  echo "[axebc2] reindex-chainstate requested" >&2
  extra="-reindex-chainstate"
  rm -f "${reindex_flag}" 2>/dev/null || true
fi

# shellcheck disable=SC2086
exec bitcoinIId "$@" $extra
