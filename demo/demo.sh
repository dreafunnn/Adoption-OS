#!/bin/bash
# adoption-os live demo
# Runs the full pipeline: seed CSV → harvest patterns → draft exec readout
#
# Usage: bash demo/demo.sh

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSV_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/adoption-os}"
CSV_FILE="$CSV_DIR/adoption-os.csv"
SESSIONS_DIR="$PLUGIN_DIR/tests/mock-sessions"

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

divider() { printf '────────────────────────────────────────────────────────────\n'; }
header()  { printf '\n'; divider; printf "  %s\n" "$1"; divider; }

fire_hook() {
  local tool="$1" target_key="$2" target_val="$3" success="$4"
  local escaped="${target_val//\"/\\\"}"  # escape embedded double quotes for JSON
  local response
  if [ "$success" = "false" ]; then
    # Use realistic error shapes: Bash uses isError+stderr, Edit/Write use is_error
    if [ "$tool" = "Bash" ]; then
      response='{"isError":true,"stdout":"","stderr":"non-zero exit code"}'
    else
      response='{"is_error":true,"content":"operation failed"}'
    fi
  else
    if [ "$tool" = "Bash" ]; then
      response='{"isError":false,"stdout":"ok","stderr":""}'
    else
      response='{"content":"ok"}'
    fi
  fi
  # Use tool_name — the field name the Claude Code runtime actually sends
  printf '{"tool_name":"%s","tool_input":{"%s":"%s"},"tool_response":%s}' \
    "$tool" "$target_key" "$escaped" "$response" \
    | bash "$PLUGIN_DIR/hooks/logger.sh"
}

# ─────────────────────────────────────────────
# Step 1: Seed the CSV with 2 weeks of sessions
# ─────────────────────────────────────────────

header "STEP 1 — Seeding session log CSV (2 weeks, 6 engineers)"

# Wipe and recreate so the demo is repeatable
rm -f "$CSV_FILE"

# Week 1: May 5–9
fire_hook Bash  command 'grep -r "rateLimit" src/'              true
fire_hook Edit  file_path src/api/routes/auth.ts                true
fire_hook Bash  command 'npm test -- --testPathPattern=auth'    true
fire_hook Bash  command 'npm run lint -- src/api/routes/auth.ts' true

fire_hook Edit  file_path src/types/user.ts                     false
fire_hook Edit  file_path src/components/ProfileCard.tsx        false
fire_hook Edit  file_path src/components/ProfileCard.tsx        true
fire_hook Bash  command 'npm test -- --testPathPattern=ProfileCard' true

fire_hook Bash  command 'git rebase origin/main'                false
fire_hook Bash  command 'git rebase origin/main'                false
fire_hook Bash  command 'git rebase origin/main'                false

fire_hook Edit  file_path infra/k8s/deployment.yaml             true
fire_hook Bash  command 'kubectl apply -f infra/k8s/deployment.yaml' false

fire_hook Bash  command 'psql -c "EXPLAIN ANALYZE SELECT ..."'  true
fire_hook Edit  file_path src/db/queries/reports.sql            true
fire_hook Bash  command 'psql -c "EXPLAIN ANALYZE SELECT ..."'  true

fire_hook Edit  file_path src/pages/DashboardPage.tsx           false
fire_hook Edit  file_path src/pages/DashboardPage.tsx           false
fire_hook Edit  file_path src/pages/DashboardPage.tsx           false

# Week 2: May 12–16
fire_hook Bash  command 'grep -r "middleware" src/'             true
fire_hook Edit  file_path src/api/routes/export.ts             true
fire_hook Bash  command 'npm test -- --testPathPattern=export'  true
fire_hook Bash  command 'npm run lint -- src/api/routes/export.ts' true

fire_hook Edit  file_path src/pages/DashboardPage.tsx           false
fire_hook Edit  file_path src/pages/DashboardPage.tsx           false
fire_hook Edit  file_path src/pages/DashboardPage.tsx           false
fire_hook Edit  file_path src/components/LoadingSpinner.tsx     true
fire_hook Bash  command 'npm test -- --testPathPattern=Dashboard' false

fire_hook Bash  command 'git rebase origin/main'                false
fire_hook Bash  command 'git rebase origin/main'                false
fire_hook Edit  file_path src/api/routes.ts                    true

fire_hook Edit  file_path infra/k8s/deployment.yaml             true
fire_hook Edit  file_path infra/k8s/deployment.yaml             false
fire_hook Bash  command 'kubectl apply -f infra/k8s/deployment.yaml' false

fire_hook Edit  file_path src/types/order.ts                   false
fire_hook Edit  file_path src/components/OrderSummary.tsx       false
fire_hook Edit  file_path src/components/OrderSummary.tsx       true
fire_hook Bash  command 'npm test -- --testPathPattern=OrderSummary' true

fire_hook Edit  file_path src/db/queries/reports.sql            true
fire_hook Bash  command 'psql -c "EXPLAIN ANALYZE SELECT ..."'  true

# CSV schema: timestamp,user,tool,target,success
total=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
successes=$(tail -n +2 "$CSV_FILE" | awk -F',' '$NF=="true"' | wc -l | tr -d ' ')
failures=$(( total - successes ))
success_pct=$(( successes * 100 / total ))

# Per-tool breakdown from column 3
top_tool="$(tail -n +2 "$CSV_FILE" \
  | awk -F',' '{print $3}' \
  | sort | uniq -c | sort -rn \
  | head -1 | awk '{print $2}')"

# Failure rate by tool — most failure-prone tool
worst_tool="$(tail -n +2 "$CSV_FILE" \
  | awk -F',' '{tool[$3]++; if($NF=="false") fail[$3]++}
               END{for(t in tool) printf "%s %.2f\n", t, fail[t]/tool[t]}' \
  | sort -k2 -rn | head -1 | awk '{print $1}')"

printf "\n  CSV seeded: %d rows | %d successes | %d failures | %d%% success rate\n" \
  "$total" "$successes" "$failures" "$success_pct"
printf "  Location: %s\n" "$CSV_FILE"

# ─────────────────────────────────────────────
# Step 2: Run pattern-harvester
# ─────────────────────────────────────────────

header "STEP 2 — Running pattern-harvester against session logs"
printf "  Analyzing: %s\n\n" "$SESSIONS_DIR"

findings="$(claude --plugin-dir "$PLUGIN_DIR" -p \
  "Run the pattern-harvester agent on $SESSIONS_DIR")"

printf '%s\n' "$findings"

# ─────────────────────────────────────────────
# Step 3: Draft exec readout with live stats
# ─────────────────────────────────────────────

header "STEP 3 — Drafting exec readout (with live CSV stats)"

claude --plugin-dir "$PLUGIN_DIR" -p \
  "/adoption-os:write-exec-readout
Findings from pattern-harvester (2 weeks, 6 engineers — alice, bob, carol, david, eve, frank):

$findings

Live session log stats: $total tool calls logged across 6 engineers over 2 weeks.
Overall success rate: ${success_pct}%. Most-used tool: ${top_tool}. Highest failure rate by tool: ${worst_tool}.
david (backend): 8/8 success rate — clean grep-first-then-edit workflow every time.
frank (frontend): 1/8 success rate, 3 abandoned tasks — missing mental model of interface propagation.
carol (infra): 2 failed kubectl applies with no dry-run step before push.
bob (backend): 5 failed git rebase attempts across 2 weeks, no diagnosis between retries.
3 teams fully onboarded this month (frontend, backend, data).
No shared skills or agents deployed yet — all standardization still manual."

divider
printf "  Demo complete.\n"
printf "  CSV at: %s\n\n" "$CSV_FILE"
