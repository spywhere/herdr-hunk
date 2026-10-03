#!/usr/bin/env bash

if test -z "$HERDR_BIN_PATH"; then
  HERDR_BIN_PATH="$(command -v herdr)"
fi

WORKSPACE_ID="$(echo "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r .workspace_id)"
WORKSPACE_CWD="$(echo "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r .workspace_cwd)"

get_config() {
  if ! test -f "$HERDR_PLUGIN_CONFIG_DIR/config.json"; then
    printf '%s' "$2"
    return
  fi
  cat "$HERDR_PLUGIN_CONFIG_DIR/config.json" | jq -r "$1 // \"$2\""
}

reviewer_panes() {
  "$HERDR_BIN_PATH" pane list --workspace "$WORKSPACE_ID" | jq -r '.result.panes|map(select(.tokens["hunk-reviewer"]=="1")|.pane_id)[]'
}

close_reviewer() {
  local panes
  panes="$(reviewer_panes)"
  if test -z "$panes"; then
    return 1
  fi
  for pane in "$panes"; do
    "$HERDR_BIN_PATH" plugin pane close "$pane"
  done
}

main() {
  local action
  action="$1"

  case "$action" in
    open)
      if test -n "$(reviewer_panes)"; then
        echo "hunk-reviewer is already opened"
        exit 1
      fi
      ;;
    toggle)
      if close_reviewer; then
        exit 0
      fi
      ;;
    close)
      close_reviewer
      exit 0
      ;;
    *)
      echo "invalid action '$action'"
      exit 1
      ;;
  esac

  local title
  case "$(get_config .initial-diff uncommitted)" in
    uncommitted)
      title="Uncommitted"
      ;;
    unpushed)
      title="Unpushed"
      ;;
    trunk)
      title="Trunk"
      ;;
  esac

  local auto_focus="--focus"
  if get_config '.auto-focus' = 'false'; then
    auto_focus=''
  fi

  local new_pane
  new_pane="$("$HERDR_BIN_PATH" plugin pane open --plugin spywhere.herdr-hunk --entrypoint hunk --placement split --direction right --cwd "$WORKSPACE_CWD" $auto_focus | jq -r .result.plugin_pane.pane)"
  "$HERDR_BIN_PATH" pane rename "$(echo "$new_pane" | jq -r .pane_id)" "Hunk Review - $title"
  "$HERDR_BIN_PATH" pane report-metadata "$(echo "$new_pane" | jq -r .pane_id)" --source 'spywhere.hunk-reviewer' --token 'hunk-reviewer=1'
}

main "$@"
