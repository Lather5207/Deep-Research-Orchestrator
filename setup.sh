#!/usr/bin/env bash
# Deep Research Orchestrator — Setup Script
#
# Usage:
#   ./setup.sh                              # Interactive (prompts for models)
#   ORCHESTRATOR_MODEL=zai/glm-5.1 \
#   SCOUT_MODEL=zai/glm-4.7 ./setup.sh      # Non-interactive

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"

echo "🔬 Deep Research Orchestrator — Setup"
echo "====================================="
echo ""

# ── Models ──
if [ -z "$ORCHESTRATOR_MODEL" ]; then
  read -p "Orchestrator model [zai/glm-5.1]: " ORCHESTRATOR_MODEL
  ORCHESTRATOR_MODEL="${ORCHESTRATOR_MODEL:-zai/glm-5.1}"
fi
if [ -z "$SCOUT_MODEL" ]; then
  read -p "Scout model [zai/glm-4.7]: " SCOUT_MODEL
  SCOUT_MODEL="${SCOUT_MODEL:-zai/glm-4.7}"
fi

echo ""
echo "Orchestrator: $ORCHESTRATOR_MODEL"
echo "Scout:        $SCOUT_MODEL"
echo "State dir:    $STATE_DIR"
echo ""

# ── 1. Create agents ──
echo "🤖 Creating agents..."
openclaw agents add deep-researcher \
  --model "$ORCHESTRATOR_MODEL" \
  --workspace "$STATE_DIR/workspace-deep-researcher" \
  --non-interactive

openclaw agents add sub-researcher \
  --model "$SCOUT_MODEL" \
  --workspace "$STATE_DIR/workspace-sub-researcher" \
  --non-interactive

# ── 2. Copy workspace files ──
echo "📝 Installing orchestrator workspace..."
cp "$SCRIPT_DIR/agents/orchestrator/workspace/"*.md "$STATE_DIR/workspace-deep-researcher/"

echo "📝 Installing scout workspace..."
cp "$SCRIPT_DIR/agents/scout/workspace/"*.md "$STATE_DIR/workspace-sub-researcher/"

echo "📝 Creating output directories..."
mkdir -p "$STATE_DIR/workspace-deep-researcher/research-reports"

# ── 3. Auth profiles ──
if [ -f "$STATE_DIR/agents/main/agent/auth-profiles.json" ]; then
  echo "🔑 Copying auth profiles from main agent..."
  mkdir -p "$STATE_DIR/agents/deep-researcher/agent"
  mkdir -p "$STATE_DIR/agents/sub-researcher/agent"
  cp "$STATE_DIR/agents/main/agent/auth-profiles.json" \
     "$STATE_DIR/agents/deep-researcher/agent/auth-profiles.json"
  cp "$STATE_DIR/agents/main/agent/auth-profiles.json" \
     "$STATE_DIR/agents/sub-researcher/agent/auth-profiles.json"
  echo "   ✅ Done"
else
  echo "⚠️  No auth-profiles.json found in main agent."
  echo "   You'll need to copy it manually:"
  echo "   cp \$STATE_DIR/agents/main/agent/auth-profiles.json \\"
  echo "      \$STATE_DIR/agents/deep-researcher/agent/"
  echo "   cp \$STATE_DIR/agents/main/agent/auth-profiles.json \\"
  echo "      \$STATE_DIR/agents/sub-researcher/agent/"
fi

# ── 4. Generate config snippet ──
echo "⚙️  Generating config snippet..."
mkdir -p "$SCRIPT_DIR/config"
cat > "$SCRIPT_DIR/config/generated.agents.json" << EOF
{
  "_comment": "Merge these into your openclaw.json",
  "agents": {
    "defaults": {
      "subagents": {
        "maxSpawnDepth": 2,
        "maxChildrenPerAgent": 15,
        "runTimeoutSeconds": 300
      }
    },
    "list": [
      {
        "id": "deep-researcher",
        "workspace": "$STATE_DIR/workspace-deep-researcher",
        "model": "$ORCHESTRATOR_MODEL",
        "skills": ["tavily"],
        "tools": {
          "allow": ["web_search", "web_fetch", "image", "exec", "read", "write", "edit"]
        },
        "subagents": {
          "allowAgents": ["sub-researcher"]
        }
      },
      {
        "id": "sub-researcher",
        "workspace": "$STATE_DIR/workspace-sub-researcher",
        "model": "$SCOUT_MODEL",
        "skills": ["tavily"],
        "tools": {
          "allow": ["web_search", "web_fetch", "image"]
        }
      }
    ]
  }
}
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Config snippet generated at config/generated.agents.json"
echo ""
echo "Merge this into your openclaw.json, then restart the gateway."
echo ""

# ── 5. Verify skills ──
echo "🔍 Checking required skills..."
for skill in tavily; do
  if [ -f "$STATE_DIR/plugin-skills/$skill/SKILL.md" ] || \
     [ -f "$HOME/.npm-global/lib/node_modules/openclaw/skills/$skill/SKILL.md" ]; then
    echo "   ✅ $skill"
  else
    echo "   ⚠️  $skill — not found. Install via: openclaw plugins install clawhub:$skill"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup complete!"
echo ""
echo "🧪 To trigger research, have your main agent spawn the deep-researcher:"
echo "   sessions_spawn({ agentId: 'deep-researcher', task: 'Research [topic]' })"
echo ""
echo "📖 Docs: cat $SCRIPT_DIR/README.md"
