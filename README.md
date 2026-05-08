# Deep Research Orchestrator

A multi-agent deep research system for OpenClaw that decomposes complex research questions into focused subtasks, delegates to scout agents, iterates on gaps, and produces comprehensive published reports.

Inspired by architectures from Anthropic, OpenAI, Google, and Perplexity. Based on 18 sources of production multi-agent research patterns.

## What's Included

| Agent | Role | Model | Tools |
|-------|------|-------|-------|
| **deep-researcher** (orchestrator) | Plans, decomposes, coordinates scouts, synthesizes, publishes | Your strongest model | web_search, web_fetch, exec, read, write, edit |
| **sub-researcher** (scout) | Focused single-topic research with self-summarization | Your cheapest capable model | web_search, web_fetch |

## Architecture

```
User → Main Agent → Deep Researcher (orchestrator)
                         │
                    Phase 1: SCOPE
                    Break into subtopics, write structured briefs
                         │
                    Phase 2: RESEARCH
                    Spawn scouts sequentially (one topic each)
                    🐦 Scout 1 → 🐦 Scout 2 → ... → 🐦 Scout N
                         │
                    Gap Review (max 2 rounds)
                    Spawn more scouts if needed
                         │
                    Phase 3: WRITE
                    Verify → Synthesize → Publish to Notion
```

## Quick Start

### 1. Install the agents

```bash
# Add orchestrator agent
openclaw agents add deep-researcher \
  --model "your-provider/your-strongest-model" \
  --workspace ~/.openclaw/workspace-deep-researcher

# Add scout agent
openclaw agents add sub-researcher \
  --model "your-provider/your-cheapest-capable-model" \
  --workspace ~/.openclaw/workspace-sub-researcher
```

### 2. Copy workspace files

```bash
# Copy orchestrator workspace
cp -r agents/deep-researcher/workspace/ ~/.openclaw/workspace-deep-researcher/

# Copy scout workspace
cp -r agents/sub-researcher/workspace/ ~/.openclaw/workspace-sub-researcher/
```

### 3. Copy auth profiles

The deep-researcher needs auth profiles to access exec, web search, etc. Copy from your main agent:

```bash
cp ~/.openclaw/agents/main/agent/auth-profiles.json \
   ~/.openclaw/agents/deep-researcher/agent/auth-profiles.json

cp ~/.openclaw/agents/main/agent/auth-profiles.json \
   ~/.openclaw/agents/sub-researcher/agent/auth-profiles.json
```

### 4. Update openclaw.json

Run setup.sh — it generates a config snippet with your model names:

```bash
ORCHESTRATOR_MODEL="your-strong-model" SCOUT_MODEL="your-cheap-model" ./setup.sh
```

Or manually: see `config/openclaw.agents.json` for the template. Adjust model names to match your provider.

### 5. Test

```bash
openclaw agent --local --agent deep-researcher \
  --message "Research the current state of Rust web frameworks. Compare Actix, Axum, Warp, and Rocket. Cover performance benchmarks, ecosystem maturity, and community sentiment. Publish to Notion." \
  --timeout 1800
```

## Key Design Principles

- **One topic per scout** — Never bundle subjects. Each scout gets exactly one focus area.
- **Structured research briefs** — Every scout receives a brief with TOPIC, OBJECTIVE, TOOLS, OUTPUT, CONSTRAINTS, EFFORT, and SUMMARIZE fields.
- **Self-summarization** — Scouts compress findings 60-80% before returning. Prevents orchestrator context bloat.
- **Hard resource limits** — 15 scouts max, 8 searches per scout, 2 gap-filling rounds, 30 minute wall clock.
- **Start wide, then narrow** — Scouts begin with broad queries, evaluate, then narrow focus.
- **Sequential scouts** — One at a time to avoid API rate limits (switch to parallel if your provider supports it).
- **One-shot synthesis** — The entire report written in a single turn to avoid context compaction.

## Customization

### Model Selection

The system uses the **advisor pattern**: expensive model plans, cheap model executes.

- **Orchestrator**: Needs your strongest model for planning, decomposition, and synthesis. This agent makes 5-10 LLM calls per run.
- **Scouts**: Can use a cheaper model. They do focused search+summarize work. Each makes 15-25 LLM calls.

### Publishing

The orchestrator publishes to Notion by default. To change the output target, edit `agents/deep-researcher/workspace/AGENTS.md` and modify Phase 3. Options:
- Remove Notion publishing, keep local Markdown only
- Add GitHub repo publishing (via exec + git)
- Add custom API endpoints

### Parallel Execution

If your model provider supports concurrent requests without rate limits, change the AGENTS.md to spawn scouts in parallel. The architecture supports it — it's a prompt change, not a code change.

## Version History

- **v1**: Naive approach with vague prompts. Inconsistent results, context overflow.
- **v2**: Structured briefs + self-summarization. Better coverage, but scouts still bundled topics.
- **v3**: Hard limits + research-backed patterns from 18 production system sources. Current version.

## Sources

This system was designed based on research into production multi-agent architectures:
- Anthropic Multi-Agent Research System (90.2% improvement over single-agent)
- OpenAI Deep Research (five-phase ReAct pipeline)
- Google Gemini Deep Research (collaborative planning)
- Perplexity Deep Research (test-time compute expansion)
- LangChain open_deep_research, HuggingFace Open Deep Research, GPT Researcher
- MAST Study (NeurIPS 2025) on multi-agent failure modes

## License

MIT — use freely, modify, share.
