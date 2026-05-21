#!/bin/bash
# PostToolUse logger — appends one row per matched tool call to the plugin's
# persistent CSV. Safe against shell injection and CSV formula injection,
# redacts common secret patterns, and truncates very long values.

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
target="$(printf '%s' "$payload" | jq -r '(.tool_input.file_path // .tool_input.command // .tool_input.pattern // "unknown")')"

# Success detection must cover all error shapes across tool types:
#   .error           — Edit/Write failures
#   .isError         — Bash failures (camelCase, most common)
#   .is_error        — alternative snake_case
#   non-zero exit    — explicit exit code if the runtime included one
#   stderr keywords  — Bash that wrote to both streams but reported a fatal error
#   stderr-only      — fallback heuristic for tools that signal failure via stderr alone
success="$(printf '%s' "$payload" | jq -r '
  .tool_response // {} |
  if .error != null then false
  elif .isError == true then false
  elif .is_error == true then false
  elif ((.exit_code // .exitCode // .returncode // 0) != 0) then false
  elif ((.stderr // "") | test("error|fatal|denied|not found|cannot|failed"; "i")) then false
  elif ((.stderr // "" | length) > 0 and (.stdout // "" | length) == 0) then false
  else true
  end
')"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
user="${USER:-unknown}"

# Best-effort secret redaction. Patterns cover the common high-value tokens
# engineers paste into shell commands. Not bulletproof — defense in depth,
# not the only line. Each match is replaced with a labelled placeholder so
# the log row still tells you "a Bearer token appeared here" without leaking it.
redact_secrets() {
  local val="$1"
  printf '%s' "$val" | sed -E \
    -e 's/sk-[A-Za-z0-9_-]{16,}/<redacted:openai-style-key>/g' \
    -e 's/ghp_[A-Za-z0-9]{20,}/<redacted:github-token>/g' \
    -e 's/gho_[A-Za-z0-9]{20,}/<redacted:github-token>/g' \
    -e 's/AKIA[0-9A-Z]{16}/<redacted:aws-access-key>/g' \
    -e 's/[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{16,}/<redacted:bearer-token>/g' \
    -e 's/eyJ[A-Za-z0-9._-]{20,}/<redacted:jwt>/g' \
    -e 's/xox[bpoa]-[A-Za-z0-9-]{10,}/<redacted:slack-token>/g'
}

# Truncate to keep one rogue paste from blowing up the CSV row size.
truncate_target() {
  local val="$1"
  local max=200
  if [ "${#val}" -gt "$max" ]; then
    printf '%s' "${val:0:$((max-3))}..."
  else
    printf '%s' "$val"
  fi
}

# CSV formula injection guard: leading =, +, -, @ trick spreadsheet apps.
sanitize_csv() {
  local val="$1"
  case "$val" in
    [=+\-@]*) printf "'%s" "$val" ;;
    *)        printf '%s' "$val" ;;
  esac
}

# Apply redaction first, then truncation, then formula sanitization.
# Order matters: redact before truncate so we don't cut a token in half
# and miss the pattern match.
target="$(redact_secrets "$target")"
target="$(truncate_target "$target")"

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
