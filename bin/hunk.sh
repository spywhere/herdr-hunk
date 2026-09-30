#!/usr/bin/env bash

if test -z "$HERDR_BIN_PATH"; then
  HERDR_BIN_PATH="$(command -v herdr)"
fi

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

main() {
  hunk diff --extension "$(dirname "$CURRENT_DIR")/extension/hunk-reviewer.ts"
}

main "$@"
