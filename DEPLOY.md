# Deploy — Fly.io + Claude Desktop MCP

> One-time setup. After this you have a live URL + Claude Desktop can call
> your research database directly.

## A. Deploy the Rails app to Fly.io

### 1. Pre-flight

```bash
fly auth whoami           # confirm you're logged in
fly orgs list             # confirm your personal org exists
```

If not logged in: `fly auth login`.

### 2. Launch the app + Postgres with pgvector

The app already has `Dockerfile` and `fly.toml` ready. Run:

```bash
cd ~/PROJECTS/great-ques-ai-researcher

# Create the app (pick a globally-unique name when prompted, e.g. research-copilot-<you>)
fly launch --no-deploy --copy-config

# Create a Managed Postgres cluster with pgvector enabled
fly mpg create --name research-copilot-pg --region iad --pgvector

# Attach the database to the app (sets DATABASE_URL secret automatically)
fly mpg attach research-copilot-pg --app <your-app-name>
```

> If `fly mpg` (Managed Postgres) isn't available on your account, fall back to:
> `fly pg create --name research-copilot-pg --image-ref flyio/postgres-flex:16.4` then
> manually `CREATE EXTENSION vector;` via `fly pg connect`.

### 3. Set secrets

```bash
fly secrets set \
  OPENAI_API_KEY="sk-..." \
  ANTHROPIC_API_KEY="sk-ant-..." \
  RAILS_MASTER_KEY="$(cat config/master.key)"
```

### 4. Deploy

```bash
fly deploy
```

The release command (`bin/rails db:prepare`) will run migrations including
the pgvector extension + HNSW index automatically.

### 5. Seed production with the demo transcripts

```bash
fly ssh console -C "bin/rails db:seed"

# Or run the Phase 2 ingestion + Phase 5 theme extraction:
fly ssh console -C "bin/rails runner 'Transcript.find_each { |t| IngestTranscriptJob.perform_now(t.id) }; ThemeExtractionJob.perform_now'"
```

### 6. Smoke test the live app

```bash
APP_URL=$(fly status --json | jq -r '.Hostname')
echo "https://$APP_URL"

curl "https://$APP_URL/up"                             # 200 ok
curl "https://$APP_URL/api/v1/themes" | jq '.count'    # should be 5
```

### 7. (Optional) Run the eval against the deployed app

The eval harness expects to run in-process. To verify the deployed instance,
SSH in and run it there:

```bash
fly ssh console -C "bin/eval"
```

You should see the same ~100% hit-rate / ~80 groundedness / ~100% citation accuracy
numbers as locally (within a couple of points of variance).

---

## B. Connect Claude Desktop to your MCP server

The MCP server is a separate Node process that runs locally on your machine and
talks to your Rails app over HTTP. You can point it at either local Rails (`bin/dev`)
or the deployed Fly app.

### 1. Build the MCP server (one-time)

```bash
cd mcp-server
npm install
npm run build
cd ..
```

### 2. Edit Claude Desktop config

Open `~/Library/Application Support/Claude/claude_desktop_config.json` and add:

```json
{
  "mcpServers": {
    "research-copilot": {
      "command": "node",
      "args": ["/Users/home/PROJECTS/great-ques-ai-researcher/mcp-server/dist/index.js"],
      "env": {
        "RESEARCH_COPILOT_URL": "https://<your-app>.fly.dev"
      }
    }
  }
}
```

For local testing, set `RESEARCH_COPILOT_URL` to `http://localhost:3000` instead.

### 3. Restart Claude Desktop

Quit + reopen. You should see "research-copilot" listed as an MCP server with 5 tools.

### 4. Try it

In Claude Desktop, type:

> Use the research-copilot tools to tell me what users complain about most during onboarding, with exact quotes.

Claude will call `find_pain_points` and `search_interviews` and synthesize an
answer from your live Rails database — with the same citations + groundedness
you see in the web UI.

---

## C. Troubleshooting

| Problem | Fix |
|---|---|
| `fly deploy` fails on `assets:precompile` | Ensure `RAILS_MASTER_KEY` is set — `fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)"` |
| pgvector extension missing on Fly Postgres | Use Managed Postgres with `--pgvector` flag, OR custom-build the postgres-flex image with pgvector (see [this guide](https://andrefbrito.medium.com/how-to-add-pgvector-support-on-fly-io-postgres-35b2ca039ab8)) |
| MCP server in Claude Desktop says "0 tools" | Check the absolute path in `claude_desktop_config.json`; check `node -v` is >= 18 |
| API endpoints return 500 in prod but work locally | Check `fly logs` — usually `OPENAI_API_KEY` secret not set |
