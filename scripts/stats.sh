#!/bin/bash
# adoption-os/scripts/stats.sh
#
# Compute summary stats from an adoption-os usage CSV. Designed to be called
# by the write-exec-readout skill (interactive) or by demo.sh (scripted), so
# both paths use the same arithmetic and present the same numbers.
#
# Usage:
#   scripts/stats.sh                          # human-readable, default CSV path
#   scripts/stats.sh /path/to/csv             # human-readable, specific CSV
#   scripts/stats.sh --shell                  # shell-sourceable: KEY='value'
#   scripts/stats.sh --shell /path/to/csv
#
# Default CSV path: $CLAUDE_PLUGIN_DATA/adoption-os.csv, falling back to
# ~/.claude/plugins/data/adoption-os/adoption-os.csv.
#
# The CSV is read but not modified. Exits 1 if the CSV is missing or empty.

set -euo pipefail

shell_mode=0
csv_arg=""
for a in "$@"; do
  case "$a" in
    --shell)  shell_mode=1 ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)        csv_arg="$a" ;;
  esac
done

CSV="${csv_arg:-${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/adoption-os}/adoption-os.csv}"

if [ ! -f "$CSV" ]; then
  echo "adoption-os stats: no CSV found at $CSV" >&2
  exit 1
fi

# CSV columns: timestamp,user,tool,target,success
# target is RFC-4180 quoted (column 4) — may contain commas. Avoid splitting on it:
# we only ever read columns 2, 3, and $NF (success). Those three columns never
# contain embedded commas, so plain awk -F',' is safe for them.

total=$(tail -n +2 "$CSV" | wc -l | tr -d ' ')

if [ "$total" -eq 0 ]; then
  echo "adoption-os stats: CSV at $CSV has no data rows yet" >&2
  exit 1
fi

successes=$(tail -n +2 "$CSV" | awk -F',' '$NF=="true"' | wc -l | tr -d ' ')
failures=$(( total - successes ))
success_pct=$(( successes * 100 / total ))

top_user=$(tail -n +2 "$CSV" \
  | awk -F',' '{print $2}' \
  | sort | uniq -c | sort -rn \
  | head -1 | awk '{print $2}')

top_tool=$(tail -n +2 "$CSV" \
  | awk -F',' '{print $3}' \
  | sort | uniq -c | sort -rn \
  | head -1 | awk '{print $2}')

if [ "$failures" -eq 0 ]; then
  worst_tool="none"
else
  worst_tool=$(tail -n +2 "$CSV" \
    | awk -F',' '{tool[$3]++; if($NF=="false") fail[$3]++}
                  END{for(t in tool) if(tool[t]>0) printf "%s %.4f\n", t, (fail[t]+0)/tool[t]}' \
    | sort -k2 -rn | head -1 | awk '{print $1}')
fi

if [ "$shell_mode" -eq 1 ]; then
  cat <<STATS
TOTAL=$total
SUCCESSES=$successes
FAILURES=$failures
SUCCESS_PCT=$success_pct
TOP_USER='$top_user'
TOP_TOOL='$top_tool'
WORST_TOOL='$worst_tool'
STATS
else
  cat <<STATS
Total tool calls: $total
Successes: $successes
Failures: $failures
Success rate: ${success_pct}%
Top user (by call count): $top_user
Most-used tool: $top_tool
Highest-failure tool: $worst_tool
STATS
fi
