#!/usr/bin/env bash

if test -z "$HERDR_BIN_PATH"; then
  HERDR_BIN_PATH="$(command -v herdr)"
fi

WORKSPACE_ID="$(echo "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r .workspace_id)"
WORKSPACE_CWD="$(echo "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r .workspace_cwd)"

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

  local new_pane
  new_pane="$("$HERDR_BIN_PATH" plugin pane open --plugin spywhere.herdr-hunk --entrypoint hunk --placement split --direction right --cwd "$WORKSPACE_CWD" --focus | jq -r .result.plugin_pane.pane)"
  "$HERDR_BIN_PATH" pane report-metadata "$(echo "$new_pane" | jq -r .pane_id)" --source 'spywhere.hunk-reviewer' --token 'hunk-reviewer=1'
}

main "$@"
