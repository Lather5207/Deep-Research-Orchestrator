#!/usr/bin/env python3
"""
Helper for the deep-researcher agent to publish reports to Notion.
Reads a Markdown report and publishes it as a Notion page.

Usage by the orchestrator (via exec):
  python3 publish-to-notion.py --title "My Report" --file report.md

Environment:
  NOTION_API_KEY - Notion API key (or reads from ~/.config/notion/api_key)
  NOTION_DATABASE_ID - Target database (default: from --database flag)
"""

import argparse, json, os, re, sys, urllib.request

def get_api_key():
    key = os.environ.get("NOTION_API_KEY")
    if key:
        return key
    keyfile = os.path.expanduser("~/.config/notion/api_key")
    if os.path.exists(keyfile):
        return open(keyfile).read().strip()
    print("Error: No NOTION_API_KEY found", file=sys.stderr)
    sys.exit(1)

def notion(method, path, body=None, api_key=None):
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Notion-Version": "2025-09-03",
    }
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(f"https://api.notion.com/v1{path}", data=data, headers=headers, method=method)
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()[:500]}", file=sys.stderr)
        return None

def md_to_blocks(md_text):
    """Convert Markdown to Notion blocks (best-effort)."""
    blocks = []
    lines = md_text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Skip empty lines
        if not stripped:
            i += 1
            continue

        # Headings
        if stripped.startswith("# "):
            blocks.append({"object":"block","type":"heading_1","heading_1":{"rich_text":[{"text":{"content":stripped[2:]}}]}})
            i += 1
        elif stripped.startswith("## "):
            blocks.append({"object":"block","type":"heading_2","heading_2":{"rich_text":[{"text":{"content":stripped[3:]}}]}})
            i += 1
        elif stripped.startswith("### "):
            blocks.append({"object":"block","type":"heading_3","heading_3":{"rich_text":[{"text":{"content":stripped[4:]}}]}})
            i += 1
        # Divider
        elif stripped == "---":
            blocks.append({"object":"block","type":"divider","divider":{}})
            i += 1
        # Code block
        elif stripped.startswith("```"):
            lang = stripped[3:].strip() or "plain text"
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i])
                i += 1
            code = "\n".join(code_lines)[:2000]  # Notion limit
            blocks.append({"object":"block","type":"code","code":{"rich_text":[{"text":{"content":code}}],"language":lang}})
            i += 1  # skip closing ```
        # Bullet list
        elif stripped.startswith("- ") or stripped.startswith("* "):
            content = stripped[2:].strip()
            blocks.append({"object":"block","type":"bulleted_list_item","bulleted_list_item":{"rich_text":[{"text":{"content":content[:2000]}}]}})
            i += 1
        # Numbered list
        elif re.match(r'^\d+\.\s', stripped):
            content = re.sub(r'^\d+\.\s', '', stripped)
            blocks.append({"object":"block","type":"numbered_list_item","numbered_list_item":{"rich_text":[{"text":{"content":content[:2000]}}]}})
            i += 1
        # Table (as code block)
        elif "|" in stripped and i + 1 < len(lines) and "---" in lines[i+1]:
            table_lines = []
            while i < len(lines) and "|" in lines[i]:
                table_lines.append(lines[i])
                i += 1
            table = "\n".join(table_lines)[:2000]
            blocks.append({"object":"block","type":"code","code":{"rich_text":[{"text":{"content":table}}],"language":"plain text"}})
        # Regular paragraph
        else:
            blocks.append({"object":"block","type":"paragraph","paragraph":{"rich_text":[{"text":{"content":stripped[:2000]}}]}})
            i += 1

    return blocks

def publish(title, md_file, database_id, api_key):
    with open(md_file) as f:
        md_text = f.read()

    # Create page
    page = notion("POST", "/pages", {
        "parent": {"database_id": database_id},
        "properties": {
            "Name": {"title": [{"text": {"content": title}}]}
        }
    }, api_key)
    if not page:
        print("Failed to create page", file=sys.stderr)
        return None

    page_id = page["id"]
    print(f"Page created: {page_id}")

    # Convert and push blocks
    blocks = md_to_blocks(md_text)
    for batch_start in range(0, len(blocks), 100):
        batch = blocks[batch_start:batch_start + 100]
        resp = notion("PATCH", f"/blocks/{page_id}/children", {"children": batch}, api_key)
        if resp:
            print(f"  Pushed {len(batch)} blocks")
        else:
            print(f"  Failed to push blocks {batch_start}-{batch_start+len(batch)}")

    url = page.get("url", f"https://notion.so/{page_id.replace('-','')}")
    print(f"Published: {url}")
    return url

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Publish Markdown report to Notion")
    parser.add_argument("--title", required=True, help="Report title")
    parser.add_argument("--file", required=True, help="Markdown file to publish")
    parser.add_argument("--database", default=os.environ.get("NOTION_DATABASE_ID", ""), help="Notion database ID")
    args = parser.parse_args()
    publish(args.title, args.file, args.database, get_api_key())
