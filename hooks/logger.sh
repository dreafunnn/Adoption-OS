#!/bin/bash
# PostToolUse logger — appends one row per Edit/Write/Bash call to the
# plugin's persistent CSV. Safe against shell injection and CSV formula injection.

set -euo pipefail

# Require jq; fail silently so a missing dep never crashes a session.
if ! command -v jq &>/dev/null; then
  echo "adoption-os logger: jq not found, skipping" >&2
  exit 0
fi

# Read full stdin payload once.
payload="$(cat)"

# Guard against empty or malformed JSON — jq exits non-zero on bad input.
if ! printf '%s' "$payload" | jq . >/dev/null 2>&1; then
  echo "adoption-os logger: malformed JSON payload, skipping" >&2
  exit 0
fi

# Extract fields with jq. Use // fallbacks so missing keys never error.
# Runtime sends tool_name; fall back to .tool for compatibility with older payloads.
tool="$(printf '%s' "$payload" | jq -r '.tool_name // .tool // "unknown"')"
target="$(printf '%s' "$payload" | jq -r '(.tool_input.file_path // .tool_input.command // "unknown")')"

# Success detection must cover all error shapes across tool types:
#   .error        — Edit/Write failures
#   .isError      — Bash failures (camelCase, most common)
#   .is_error     — alternative snake_case
#   stderr non-empty + stdout empty — Bash non-zero exit heuristic
success="$(printf '%s' "$payload" | jq -r '
  .tool_response // {} |
  if .error != null then false
  elif .isError == true then false
  elif .is_error == true then false
  elif ((.stderr // "" | length) > 0 and (.stdout // "" | length) == 0) then false
  else true
  end
')"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
user="${USER:-unknown}"

# CSV formula injection guard: leading =, +, -, @ trick spreadsheet apps.
sanitize_csv() {
  local val="$1"
  case "$val" in
    [=+\-@]*) printf "'%s" "$val" ;;
    *)        printf '%s' "$val" ;;
  esac
}

tool_safe="$(sanitize_csv "$tool")"
target_safe="$(sanitize_csv "$target")"
success_safe="$(sanitize_csv "$success")"

# Write to plugin data dir, not the project working directory.
csv_dir="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/adoption-os}"
mkdir -p "$csv_dir"
csv_file="$csv_dir/adoption-os.csv"

# Create with header if it doesn't exist yet.
if [ ! -f "$csv_file" ]; then
  printf 'timestamp,user,tool,target,success\n' > "$csv_file"
fi

# Escape inner double quotes per RFC 4180 before wrapping field in double quotes.
target_escaped="${target_safe//\"/\"\"}"

# Append row.
printf '%s,%s,%s,"%s",%s\n' \
  "$timestamp" \
  "$user" \
  "$tool_safe" \
  "$target_escaped" \
  "$success_safe" >> "$csv_file"
