#!/usr/bin/env bash

set -euo pipefail

TARGET_FILE="${1:-assets/macos/Kaku.app/Contents/Resources/kaku.lua}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

extract_handler_block() {
  local start_pattern="$1"
  local end_pattern="$2"

  awk -v start="$start_pattern" -v end="$end_pattern" '
    $0 ~ start { in_block = 1 }
    in_block { print }
    in_block && $0 ~ end { exit }
  ' "$TARGET_FILE"
}

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    echo "$haystack" >&2
    fail "$label missing: $needle"
  fi
}

assert_not_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if grep -Fq "$needle" <<<"$haystack"; then
    echo "$haystack" >&2
    fail "$label unexpectedly contains: $needle"
  fi
}

full_text="$(cat "$TARGET_FILE")"
assert_not_contains "kaku.lua" "local function is_shell_foreground(pane)" "$full_text"

failed_handler_block="$(extract_handler_block \
  "if name ~= \"kaku_last_exit_code\" then" \
  "pane_state\\.inflight = true")"
[[ -n "$failed_handler_block" ]] || fail "failed-command AI handler block not found"
assert_contains "failed-command AI handler" "Do not gate on pane:get_foreground_process_name() here." "$failed_handler_block"
assert_not_contains "failed-command AI handler" "if not is_shell_foreground(pane) then" "$failed_handler_block"

generate_handler_block="$(extract_handler_block \
  "if name ~= \"kaku_ai_query\" then" \
  "pane_state\\.inflight = true")"
[[ -n "$generate_handler_block" ]] || fail "command-generation AI handler block not found"
assert_not_contains "command-generation AI handler" "if not is_shell_foreground(pane) then" "$generate_handler_block"

echo "AI tmux shell origin gate smoke tests passed"
