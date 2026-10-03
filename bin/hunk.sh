#!/usr/bin/env bash

get_config() {
  if ! test -f "$HERDR_PLUGIN_CONFIG_DIR/config.json"; then
    printf '%s' "$2"
    return
  fi
  cat "$HERDR_PLUGIN_CONFIG_DIR/config.json" | jq -r "$1 // \"$2\""
}

PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"
additional_paths="$(get_config '.path')"
if test -n "$additional_paths"; then
  PATH="$PATH:$additional_paths"
fi

main() {
  local revset
  case "$(get_config .initial-diff uncommitted)" in
    uncommitted)
      revset=''
      ;;
    unpushed)
      revset="remote_bookmarks(remote='$(get_config .default-remote origin)')..@"
      ;;
    trunk)
      revset='trunk()..@'
      ;;
  esac
  local fast='--fast'
  if test "$(get_config .fast)" = 'false'; then
    fast=''
  fi
  local auto_reload
  if test "$(get_config .auto-reload)" = 'true'; then
    auto_reload='--watch'
  fi
  local mode
  mode="$(get_config .mode)"
  if test -n "$mode"; then
    mode="--mode '$mode'"
  fi
  hunk diff --extension "$HERDR_PLUGIN_ROOT/herdr-reviewer" $fast $auto_reload $mode $revset
  if test $? -ne 0; then
    read
  fi
}

main "$@"
