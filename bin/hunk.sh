#!/usr/bin/env bash

if test -z "$HERDR_BIN_PATH"; then
  HERDR_BIN_PATH="$(command -v herdr)"
fi

get_config() {
  if ! test -f "$HERDR_PLUGIN_CONFIG_DIR/config.json"; then
    return
  fi
  cat "$HERDR_PLUGIN_CONFIG_DIR/config.json" | jq -r "$1"
}

PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"
additional_paths="$(get_config '.path')"
if test -n "$additional_paths"; then
  PATH="$PATH:$additional_paths"
fi

main() {
  hunk diff --extension "$HERDR_PLUGIN_ROOT"
  if test $? -ne 0; then
    read
  fi
}

main "$@"
