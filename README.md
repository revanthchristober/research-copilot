# Research Copilot

> A mini Great Question — semantic search, evidence-backed Q&A, auto-extracted themes, and a groundedness eval harness for customer interview transcripts. Built in 1 sprint as a demo for the **AI Engineer Intern role at Great Question (W21)**.

🌐 **Live demo:** [research-copilot-sl2n.onrender.com](https://research-copilot-sl2n.onrender.com) *(free tier — 30s cold start)*
📊 **Eval results:** [`evals/results.md`](evals/results.md) — 100% retrieval hit-rate, 100% citation accuracy, ~80/100 groundedness on 10 hand-curated golden Q&A pairs
🔌 **MCP server:** [`mcp-server/`](mcp-server/) — exposes the corpus to Claude Desktop as 5 tools

---

## Why this exists

The Great Question JD explicitly calls out four AI projects their intern would tackle:

| JD project | What I built |
|---|---|
| *Semantic search across tens of thousands of interview hours* | pgvector + HNSW cosine + optional `gpt-4o-mini` reranker — `/api/v1/search` |
| *MCP tool structuring and prompt tuning* | Stdio MCP server in Node/TS exposing 5 tools that wrap the Rails API |
| *Setting up evals and quality measures* | `bin/eval` runs a 10-question golden set in parallel, produces a markdown report with three metrics |
| *Realtime agentic AI moderator (TTS/STT/Vision)* | Out of scope for a 1-week sprint, but the architecture supports adding it as a new service |

I picked Great Question's actual product surface (interview research, RAG with citations, theme extraction) instead of building a generic AI chatbot, because the JD said *"show how you engaged with what we're building."*

---

## What it does

### 1. Ingest interviews

Paste plain text, WEBVTT, or SRT. The pipeline auto-detects the format, parses speaker turns, chunks (~500-token windows w/ 50-token overlap, speaker-aware), enqueues async OpenAI embedding jobs, and lights up a live progress bar via Turbo Streams.

### 2. Semantic search

Type a query in the header — semantic ranking via pgvector cosine with HNSW index. Optional `gpt-4o-mini` reranker for higher precision at the top.

### 3. Ask a research question

POST a question → `AnswerService` retrieves top-8 chunks, calls `gpt-4o` with a strict JSON schema (`{ answer, citations: [{chunk_id, quote}] }`), validates every citation chunk_id, and persists the answer. The UI loads it via a lazy Turbo Frame so the page renders instantly while the answer streams in 5-10s later. Every answer ships with inline `[1] [2] [3]` markers linked to verbatim quote popovers.

### 4. Auto-extracted themes

`ThemeExtractionJob` runs `gpt-4o` over the whole corpus, returns 5-10 clustered themes with confidence scores + supporting `chunk_ids`. Visible at `/themes`.

### 5. Groundedness eval

Every answer is scored 0-100 by an independent `gpt-4o-mini` judge with a rubric prompt — penalises paraphrases, unsupported framings, fabricated entities. Hand-tested against obvious hallucinations (returns 0). The score is shown as a colored badge next to every answer in the UI.

### 6. Eval harness

`bin/eval` runs a 10-question golden set in parallel (5-concurrent threads), computes three metrics, and writes `evals/results.md`:

```
Retrieval hit-rate @ k=5:   100.0%   ← 10/10 golden questions had expected snippet in top-5
Groundedness avg:           76.0/100 ← independent gpt-4o-mini judge
Citation accuracy:          100.0%   ← 26/26 quotes are verbatim substrings of cited chunks
Runtime:                    17.2s    ← parallel
```

### 7. MCP server

`mcp-server/` is a Node/TS process speaking the Model Context Protocol over stdio. Exposes 5 tools to Claude Desktop: `search_interviews`, `get_quotes`, `find_pain_points`, `find_feature_requests`, `ask_research_question`. Each tool wraps a JSON endpoint on the Rails app.

---

## Architecture

```
┌─────────────────────── Rails 8 monolith ───────────────────────┐
│                                                                 │
│  React-Tailwind UI (jsbundling-rails + esbuild + Tailwind v4)  │
│       ↓ Turbo Frames / fetch                                    │
│  Rails controllers + ActiveRecord                               │
│       ↓                                                         │
│  ┌─ Ingestion ──────┐   ┌─ Query ────────────────┐             │
│  │ parse → chunk    │   │ embed query (OpenAI)   │             │
│  │ → enqueue        │   │ → pgvector HNSW search │             │
│  │ → async embed    │   │ → gpt-4o JSON-schema   │             │
│  │   (OpenAI)       │   │ → groundedness judge   │             │
│  │ → progress       │   │   (gpt-4o-mini)        │             │
│  │   broadcast      │   │ → persist Answer       │             │
│  └──────────────────┘   └────────────────────────┘             │
│                                                                 │
│  Supabase Postgres 17 + pgvector + HNSW cosine                 │
└─────────────────────────────────────────────────────────────────┘
                          ▲
                          │ stdio JSON-RPC
              ┌───────────┴────────────────┐
              │  MCP server (Node/TS)      │
              │  → Claude Desktop          │
              └────────────────────────────┘
```

**LLM adapter pattern**: every model call goes through `LLM.complete` / `LLM.complete_with_schema` / `LLM.embed` in [`app/services/llm.rb`](app/services/llm.rb). Swap OpenAI → Anthropic in one file. Different models per environment via `LLM_GENERATION_MODEL` env (local uses `gpt-5`, prod uses `gpt-4o-mini` to fit Render's proxy window).

---

## Stack

| Layer | Pick |
|---|---|
| Backend | Rails 8.0.5, Ruby 3.3.6 |
| Frontend | React/TS + Tailwind v4 via jsbundling/cssbundling |
| DB | Postgres 17 + pgvector 0.8 (HNSW cosine), single instance (Supabase free) |
| LLM | OpenAI `gpt-5` (local) / `gpt-4o-mini` (prod) — for generation, `gpt-4o-mini` for judge + rerank, `text-embedding-3-small` for embeddings |
| Async | Solid Queue locally; in-process `:async` adapter on Render (single-instance free tier) |
| MCP | `@modelcontextprotocol/sdk` v1.16, Zod-validated tools, stdio transport |
| Hosting | Render (web) + Supabase (Postgres), both free tier |
| Eval | Custom Rake task w/ `Concurrent::Semaphore` for 5-way parallel evaluation |

---

## Run locally

```bash
git clone https://github.com/revanthchristober/research-copilot
cd research-copilot
mise install                                    # Ruby 3.3.6
bundle && npm install
bin/rails db:create db:migrate db:seed          # local Postgres
echo "OPENAI_API_KEY=sk-..." >> .env
bin/dev                                         # → http://localhost:3000
```

Run the eval:

```bash
bin/eval                                        # ~17s, writes evals/results.md
```

Run the MCP server against your local Rails:

```bash
cd mcp-server
npm install && npm run build
node dist/index.js                              # speaks MCP over stdio
```

To register with Claude Desktop, see [`mcp-server/README.md`](mcp-server/README.md).

---

## What I'd build next (if hired)

In rough order of impact:

1. **Speaker diarisation + Whisper** for actual audio upload (right now only text/VTT/SRT — Beta would need audio)
2. **Cross-interview clustering UI** — themes are flat; should be a tree (theme → sub-theme → quote)
3. **Realtime moderator** — `gpt-5` with streaming TTS + Deepgram STT to actually conduct a Zoom interview, taking notes and asking follow-ups (the Phase 6 stretch I cut for time)
4. **Multi-tenant + auth** — Devise + row-level workspace scoping
5. **Scale retrieval to 10k+ hours** — chunked HNSW shards, Cohere reranker
6. **Move groundedness judge to a fine-tuned smaller model** — current `gpt-4o-mini` is overkill for the rubric

---

## Phase log

Built in 7 phases. Each commit on `main` corresponds to a closed phase ([PHASES.md](PHASES.md)).

| Phase | Outcome |
|---|---|
| 0 | Rails 8 + Postgres + pgvector wired |
| 1 | Models + LLM adapter |
| 2 | Ingestion pipeline w/ Turbo Streams progress |
| 3 | Semantic search + HNSW + rerank |
| 4 | Q&A with strict JSON-schema citations |
| 5 | Themes + groundedness judge + `bin/eval` |
| 6 | `/api/v1/*` + MCP server + Render+Supabase deploy |
| 7 | This README, application submitted |

---

Built by [Revanth Christopher](https://github.com/revanthchristober) for the Great Question (W21) AI Engineer Intern application.
