# Research Copilot — MCP server

Exposes Research Copilot's interview database as tools for Claude Desktop
(or any MCP client) via the [Model Context Protocol](https://modelcontextprotocol.io).

## Tools

| Tool | What it does |
|---|---|
| `search_interviews(query, k)` | Semantic search across all interviews — returns top-k chunks with similarity scores. |
| `get_quotes(chunk_ids)` | Fetch full chunk text by ID. |
| `find_pain_points()` | List the auto-extracted recurring themes with evidence counts. |
| `find_feature_requests(k)` | Search for chunks where users requested features or improvements. |
| `ask_research_question(question)` | Full RAG: synthesizes an answer with citations + a 0-100 groundedness score. |

## Setup

```bash
cd mcp-server
npm install
npm run build
```

## Run

The MCP server talks to the running Rails app over HTTP.

```bash
# Make sure the Rails app is running on localhost:3000
cd ..
bin/dev

# In another terminal, test the MCP server interactively (optional)
cd mcp-server
RESEARCH_COPILOT_URL=http://localhost:3000 npm start
```

## Register with Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "research-copilot": {
      "command": "node",
      "args": ["/Users/home/PROJECTS/great-ques-ai-researcher/mcp-server/dist/index.js"],
      "env": {
        "RESEARCH_COPILOT_URL": "http://localhost:3000"
      }
    }
  }
}
```

Then restart Claude Desktop. You should see "research-copilot" listed under
the MCP servers section, with all 5 tools available.

## Try it in Claude Desktop

> "Use the research-copilot tools to tell me what users complain about most during onboarding, with quotes."

Claude will call `find_pain_points` and `search_interviews` and synthesize
an answer from the live Rails database.
