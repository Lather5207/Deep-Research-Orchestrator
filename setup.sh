#!/usr/bin/env bash
# Deep Research Orchestrator — Setup Script
# Reads openclaw-package.yaml to install the multi-agent system
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

# ── 1. Create workspace directories ──
echo "📁 Creating workspace directories..."
mkdir -p "$STATE_DIR/workspace-deep-researcher"
mkdir -p "$STATE_DIR/workspace-sub-researcher"
mkdir -p "$STATE_DIR/workspace-deep-researcher/scripts"
mkdir -p "$STATE_DIR/workspace-deep-researcher/reports"

# ── 2. Copy workspace files ──
echo "📝 Installing orchestrator workspace..."
cp "$SCRIPT_DIR/agents/orchestrator/workspace/"*.md "$STATE_DIR/workspace-deep-researcher/"

echo "📝 Installing scout workspace..."
cp "$SCRIPT_DIR/agents/scout/workspace/"*.md "$STATE_DIR/workspace-sub-researcher/"

echo "📝 Installing helper scripts..."
cp "$SCRIPT_DIR/scripts/publish-to-notion.py" "$STATE_DIR/workspace-deep-researcher/scripts/"

# ── 3. Generate agent config ──
echo "⚙️  Generating agent config..."
cat > "$SCRIPT_DIR/config/generated.agents.json" << EOF
{
  "_comment": "Add these entries to your openclaw.json under agents.list",
  "agents": {
    "list": [
      {
        "id": "deep-researcher",
        "workspace": "$STATE_DIR/workspace-deep-researcher",
        "model": "$ORCHESTRATOR_MODEL",
        "skills": ["deep-research", "notion", "tavily"],
        "tools": {
          "allow": ["web_search", "web_fetch", "image", "exec", "read", "write", "edit"]
        }
      },
      {
        "id": "sub-researcher",
        "workspace": "$STATE_DIR/workspace-sub-researcher",
        "model": "$SCOUT_MODEL",
        "skills": [],
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
echo "📋 Agent config generated at config/generated.agents.json"
echo ""
echo "Merge this into your openclaw.json:"
echo ""
cat "$SCRIPT_DIR/config/generated.agents.json"
echo ""

# ── 4. Auth profiles ──
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

# ── 5. Verify skills ──
echo ""
echo "🔍 Checking required skills..."
for skill in deep-research notion tavily; do
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
echo "🧪 Test with:"
echo "   openclaw agent --local --agent deep-researcher \\"
echo "     --message 'Research [your topic] and publish to Notion' \\"
echo "     --timeout 1800"
echo ""
echo "📖 Docs: cat $SCRIPT_DIR/README.md"
echo "📦 Manifest: cat $SCRIPT_DIR/openclaw-package.yaml"
