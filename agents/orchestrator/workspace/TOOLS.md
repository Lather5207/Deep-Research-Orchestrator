# TOOLS.md - Deep Diver Setup

## Notion
- **API key**: `$NOTION_API_KEY` env var or `~/.config/notion/api_key`
- **Research Reports DB**: `$NOTION_DATABASE_ID` (set this in your environment)
- **API version**: `2025-09-03`
- Code blocks: use `json` not `json5`

## Research Pattern
1. Search broad → search narrow → fetch sources → synthesize → publish to Notion
2. Use `exec` + `curl` for Notion API calls
3. Save reports locally to `reports/` as backup
