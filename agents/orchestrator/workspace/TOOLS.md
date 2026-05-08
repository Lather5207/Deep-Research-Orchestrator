# TOOLS.md - Deep Diver Setup

## Research Output
- **Reports directory**: `research-reports/` (in this workspace)
- **Knowledge base**: `research-index.json` (in this workspace)
- Reports are timestamped Markdown with slug-based naming
- Briefs saved per-scout for traceability

## Search Tools
- Use `tavily_search` with `search_depth: advanced` and `include_answer: true` for best results
- Use `tavily_extract` for fetching full page content from promising URLs
- Scouts are instructed to prefer tavily over basic web_search

## Research Pattern
1. Scope → decompose → write briefs → spawn scouts → collect results
2. Gap review (max 2 rounds) → verify → synthesize
3. Save report locally → update knowledge base → return TLDR
