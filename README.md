# Deep Research Orchestrator

A multi-agent deep research system for OpenClaw that decomposes complex research questions into focused subtasks, delegates to scout agents via native sub-agent spawning, iterates on gaps, and produces comprehensive Markdown reports saved locally with a persistent knowledge base.

## What's Included

| Agent | Role | Model | Tools |
|-------|------|-------|-------|
| **deep-researcher** (orchestrator) | Plans, decomposes, coordinates scouts, synthesizes, saves reports | Your strongest model | web_search, web_fetch, exec, read, write, edit, sessions_spawn |
| **sub-researcher** (scout) | Focused single-topic research with self-summarization | Your cheapest capable model | web_search, web_fetch, tavily_search, tavily_extract |

## Architecture

```
User → Main Agent → Deep Researcher (depth-1 sub-agent)
                         │
                    Phase 1: SCOPE
                    Intent enrichment + knowledge base lookup
                    Break into subtopics, write structured briefs
                         │
                    Phase 2: RESEARCH
                    Spawn scouts via sessions_spawn (parallel, push-based completion)
                    🐦 Scout 1  🐦 Scout 2  🐦 Scout 3  ...  🐦 Scout N
                         │
                    Gap Review (max 2 rounds)
                    Spawn more scouts if needed
                         │
                    Phase 3: WRITE
                    Verify → Synthesize → Save Markdown report → Update knowledge base
```

### Sub-Agent Nesting

```
Main Agent (depth 0)
  └── sessions_spawn({ agentId: "deep-researcher", task: "Research X" })
        └── Deep Researcher (depth 1, orchestrator)
              ├── sessions_spawn({ agentId: "sub-researcher", task: brief-1 })
              ├── sessions_spawn({ agentId: "sub-researcher", task: brief-2 })
              └── sessions_spawn({ agentId: "sub-researcher", task: brief-3 })
                    └── Scouts (depth 2, leaf-only: search + fetch + summarize)
```

Scouts run under the `sub-researcher` agent — they use its model (cheaper), its tool allowlist (search/fetch only), and its workspace files. Completion is **push-based**: scouts announce results back to the orchestrator automatically. No polling required.

## Output Structure

Reports are saved in the orchestrator's workspace:

```
~/.openclaw/workspace-deep-researcher/
  ├── research-index.json                        ← knowledge base (auto-updated)
  └── research-reports/
      └── 2026-05-08_0540_rust-web-frameworks/
          ├── 2026-05-08_0540_rust-web-frameworks.md
          ├── briefs/
          │   ├── scout-01_actix.md
          │   └── ...
          └── sources.md
```

The knowledge base (`research-index.json`) accumulates findings across runs so follow-up research can build on prior work.

## Quick Start

### 1. Run setup

```bash
ORCHESTRATOR_MODEL="your-strong-model" SCOUT_MODEL="your-cheap-model" ./setup.sh
```

This creates the agents, copies workspace files, and generates a config snippet.

### 2. Merge config

Merge the generated config into your `openclaw.json`:

```json5
{
  "agents": {
    "defaults": {
      "subagents": {
        "maxSpawnDepth": 2,          // allow depth-1 → depth-2 nesting
        "maxChildrenPerAgent": 15,   // up to 15 parallel scouts
        "runTimeoutSeconds": 300     // 5 min per scout
      }
    },
    "list": [
      {
        "id": "deep-researcher",
        "model": "your-strong-model",
        "skills": ["tavily"],
        "tools": { "allow": ["web_search", "web_fetch", "image", "exec", "read", "write", "edit"] },
        "subagents": { "allowAgents": ["sub-researcher"] }
      },
      {
        "id": "sub-researcher",
        "model": "your-cheap-model",
        "skills": ["tavily"],
        "tools": { "allow": ["web_search", "web_fetch", "image"] }
      }
    ]
  }
}
```

### 3. Restart gateway

```bash
openclaw gateway restart
```

### 4. Trigger research

Have your main agent spawn the deep-researcher:

```
sessions_spawn({
  agentId: "deep-researcher",
  task: "Research the current state of Rust web frameworks. Compare Actix, Axum, Warp, and Rocket."
})
```

## Key Design Principles

- **Native sub-agent spawning** — uses `sessions_spawn` instead of CLI subprocess calls. Push-based completion, proper isolation, parallel execution.
- **Cross-agentId targeting** — orchestrator spawns scouts under the `sub-researcher` agent, giving them a cheaper model and restricted tool set.
- **One topic per scout** — Never bundle subjects. Each scout gets exactly one focus area.
- **Structured research briefs** — Every scout receives a brief with TOPIC, OBJECTIVE, TOOLS, OUTPUT, CONSTRAINTS, EFFORT, and SUMMARIZE fields.
- **Self-summarization** — Scouts compress findings 60-80% before returning. Prevents orchestrator context bloat.
- **Tavily advanced search** — Scouts prefer `tavily_search` with `search_depth: advanced` and `include_answer: true` for higher relevance and built-in AI summaries.
- **Source credibility tiers** — Scouts assess source credibility (official docs > established outlets > blogs/forums).
- **Hard resource limits** — 15 scouts max, 8 searches per scout, 2 gap-filling rounds, 30 minute wall clock.
- **Intent enrichment** — Vague user queries are expanded into imperative step-by-step scout instructions before decomposition.
- **Persistent knowledge base** — Every run updates `research-index.json` so future runs can build on past findings.
- **Local Markdown output** — Reports saved as timestamped, slug-named Markdown files with per-scout briefs and deduplicated sources.

## Customization

### Model Selection

The system uses the **advisor pattern**: expensive model plans, cheap model executes.

- **Orchestrator**: Needs your strongest model for planning, decomposition, and synthesis. Makes 5-10 LLM calls per run.
- **Scouts**: Can use a cheaper model. They do focused search+summarize work. Each makes 15-25 LLM calls.

### Output Target

Reports save as local Markdown by default. To change the output target, edit `agents/orchestrator/workspace/AGENTS.md` Phase 3. Options:
- Add Notion publishing (via exec + curl)
- Add GitHub repo publishing (via exec + git)
- Add custom API endpoints

### Parallel vs Sequential Scouts

Scouts are spawned in parallel by default (all at once, push-based completion). To serialize them instead, spawn one at a time and wait for each completion before spawning the next.

## Skills Required

| Skill | Purpose | Install |
|-------|---------|---------|
| **tavily** | Advanced web search with depth control and AI answer summaries | `openclaw plugins install clawhub:tavily` |

## Version History

- **v1**: Naive approach with vague prompts. Inconsistent results, context overflow.
- **v2**: Structured briefs + self-summarization. Better coverage, but scouts still bundled topics.
- **v3**: Hard limits + research-backed patterns from 18 production system sources.
- **v4**: Native `sessions_spawn` replacing CLI subprocess calls. Cross-agentId targeting. Tavily advanced search. Source credibility tiers. Intent enrichment. Persistent knowledge base. Local Markdown output.

## Sources

This system was designed based on research into production multi-agent architectures:
- Anthropic Multi-Agent Research System (90.2% improvement over single-agent)
- OpenAI Deep Research (five-phase ReAct pipeline)
- Google Gemini Deep Research (collaborative planning)
- Perplexity Deep Research (test-time compute expansion)
- LangChain open_deep_research, HuggingFace Open Deep Research, GPT Researcher
- MAST Study (NeurIPS 2025) on multi-agent failure modes
- Yutori Scouts (fan-out search, enriched intent, sub-agent specialization)
- Trilogy AI Multi-Agent Deep Research Architecture (parallel tree search, cycling summarization)

## License

MIT — use freely, modify, share.
