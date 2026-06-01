# Research Copilot — a Mini Great Question

> Upload customer interviews. Ask questions. Get answers with quoted evidence and a confidence score.

A lightweight AI research-intelligence tool built as a demo for the **Great Question AI Engineer Intern** application. It maps directly to 3 of the 4 example projects in the JD: **semantic search across interview hours**, **MCP tool structuring**, and **evals + quality measures**.

---

## 1. The pitch (one sentence)

A web app where a researcher uploads N interview transcripts and immediately gets a searchable, query-able "research brain" that answers questions with *exact quotes* + a *groundedness score* — the same kind of feature Great Question would ship to customers.

---

## 2. Core features (MVP — must ship)

| # | Feature | Why it lands |
|---|---------|-------------|
| 1 | **Upload transcripts** (`.txt`, `.vtt`, `.srt`, or paste) | Real research data shape — not toy text |
| 2 | **Chunk + embed + store** in pgvector | Shows retrieval pipeline thinking |
| 3 | **Semantic search UI** — type a phrase, get ranked quotes | Mirrors GQ's "search 10k interview hours" use case |
| 4 | **Q&A with evidence** — ask a question, get an answer with inline citations to source quote + speaker + timestamp | RAG with grounding, the production-quality version |
| 5 | **Theme extraction** — auto-cluster recurring pain points across transcripts | The "insight generation" workflow GQ sells |
| 6 | **Groundedness eval** — every generated insight is scored by an LLM-as-judge for evidence support, and the score is shown in the UI | This is the part 95% of demo applicants skip — and the JD explicitly calls it out |

---

## 3. Stretch goals (if time allows)

- **MCP server** — expose `search_interviews`, `get_quotes`, `find_pain_points`, `find_feature_requests` as MCP tools, connect from Claude Desktop and record a 30-sec clip of it working. Directly hits "MCP tool structuring and prompt tuning."
- **Realtime voice mode** — Web Speech API for STT + gpt-4o for live follow-up questions, demoing the "agentic AI moderator" angle.
- **Eval dashboard** — small page showing groundedness scores over time, retrieval hit-rate, and a tiny test set of golden Q→A pairs.

Don't build all three. Pick the **MCP server** as the first stretch — it's the highest signal-per-hour for this specific company.

---

## 4. Stack (concrete picks — Rails-first, mirrors GQ's actual architecture)

| Layer | Pick | Why |
|---|---|---|
| Backend | **Rails 8 (full-stack, not API-mode)** | CTO PJ Murray is a Rails guy (10+ years). Matches GQ's actual production stack |
| Frontend | **React + TypeScript + Tailwind** via `jsbundling-rails` + esbuild | Same pattern GQ uses — Rails monolith with React mounted on pages |
| DB | **Postgres 16 + pgvector** via the [`neighbor`](https://github.com/ankane/neighbor) gem | Native vector search inside Rails, no external service |
| Background jobs | **SolidQueue** (Rails 8 built-in, Postgres-backed) | No Redis needed, ingestion + embedding runs async |
| LLM (primary) | **OpenAI `gpt-4o`** for Q&A + theme extraction, **`gpt-4o-mini`** for LLM-as-judge + reranking | Both available on day-1, JSON mode + function-calling work great for citations |
| LLM client | [`ruby-openai`](https://github.com/alexrudall/ruby-openai) gem + a thin `LLM` adapter (see below) | Provider-agnostic — adapter wraps OpenAI now, can route to Anthropic (`anthropic` gem already in Gemfile) in 1 line when credits are available |
| Embeddings | **OpenAI `text-embedding-3-small`** via [`ruby-openai`](https://github.com/alexrudall/ruby-openai) | Cheap, fast, good enough |
| File storage | **Cloudflare R2** (S3-compatible) via ActiveStorage | Free egress, modern S3 replacement — beats Heroku/AWS combo |
| STT (stretch) | **Deepgram** or local **Whisper** (faster-whisper) | Modern alternatives to GCP STT — show you've evaluated options |
| Hosting | **Fly.io** (Rails + Postgres + Volume support natively, deploys in 1 command) | Modern Heroku replacement — `fly launch` and you're live |
| MCP server (stretch) | Tiny **Node/TS** sidecar in `/mcp-server` that calls Rails API endpoints | MCP SDK is best in TS; cleanest path |
| Eval | LLM-as-judge with structured JSON output, results committed to `evals/results.md` | Simple, defensible, presentable |

**Why Rails 8 not Rails 6?** GQ runs Rails 6 in prod but for a new repo built in 2026, Rails 8 is the default. The CTO will recognize you chose the modern path — built-in SolidQueue/SolidCache, no Redis dependency, Propshaft. Mention in the README you'd downgrade to match prod for the internship.

**Note on AI-assisted Rails dev:** AI can write 90% of this, but you'll still need to read stack traces and run `bin/rails console` to debug. Budget 1 extra day vs Next.js for unfamiliar idioms (ActiveRecord, migrations, ActionDispatch).

---

## 5. Architecture (one diagram, in words)

```
┌─────────────────────── Rails 8 monolith ──────────────────────┐
│                                                                │
│  React/TS UI (jsbundling-rails + esbuild + Tailwind)          │
│       ↓ Turbo / fetch                                          │
│  Rails controllers + ActiveRecord                              │
│       ↓                                                        │
│  ┌─ Ingestion ────────────┐   ┌─ Query ──────────────────┐   │
│  │ Upload → ActiveStorage │   │ User Q → embed (OpenAI)  │   │
│  │  (R2) → parse → chunk  │   │  → pgvector top-k        │   │
│  │  → SolidQueue job:     │   │  → gpt-4o (via LLM       │   │
│  │  embed (OpenAI) →      │   │    adapter) w/ retrieved │   │
│  │                        │   │    chunks                │   │
│  │  pgvector (neighbor)   │   │  → answer + citations    │   │
│  └────────────────────────┘   │  → LLM-as-judge scores   │   │
│                                │    groundedness          │   │
│                                └──────────────────────────┘   │
│                                                                │
│  Postgres 16 + pgvector + SolidQueue tables                   │
└────────────────────────────────────────────────────────────────┘
                              ▲
                              │ HTTP (internal)
              ┌───────────────┴────────────────┐
              │  Node MCP server (stretch)     │
              │  Exposes: search_interviews,   │
              │  get_quotes, find_pain_points  │
              │  → calls Rails API endpoints   │
              └────────────────────────────────┘
```

Deploys as a single Fly.io app + Postgres. MCP server is a separate tiny process you run locally for the demo (Claude Desktop connects via stdio).

---

## 6. Eval design (the part that wins it)

Build a tiny eval harness:

1. **Golden set** — 10 hand-written Q&A pairs against your seed transcripts. Each has a known correct answer + expected source chunk(s).
2. **Metrics**
   - *Retrieval hit-rate*: did top-k include the expected chunk?
   - *Groundedness*: LLM-as-judge scores 0–100 on whether the answer is supported by retrieved quotes.
   - *Citation accuracy*: are the cited quotes actually in the source?
3. **Output** — a markdown report committed in `/evals/results.md`, regenerated by `pnpm eval`.

Mention this prominently in the README. It's the single biggest differentiator.

---

## 7. Seed data (don't skip this)

Use **5 real, publicly available customer interviews** — pick a niche so insights cluster:
- YouTube SaaS customer interviews (Lenny's Podcast guest segments, First Round Review interviews)
- Or scrape 5 long-form App Store / G2 reviews of a known product

Transcribe with Whisper if needed. **Pre-populate the demo** so the reviewer doesn't have to upload anything to see it work.

---

## 8. Demo video (5 min, scripted)

| Time | Beat |
|---|---|
| 0:00–0:20 | "Hi, I'm X. I built a mini Great Question to apply for the AI Engineer Intern role. Here's what it does." |
| 0:20–1:00 | Show pre-loaded transcripts. Run semantic search: *"onboarding confusion"* → ranked quotes appear with speaker + timestamp |
| 1:00–2:00 | Ask a research question: *"What are the top 3 onboarding pain points?"* → answer with inline citations + groundedness score (e.g. 94%) |
| 2:00–3:00 | Show theme extraction running across all transcripts → clustered themes with evidence counts |
| 3:00–4:00 | **Open Claude Desktop**, show MCP tools listed, ask the same question through Claude — it calls your MCP tools and answers |
| 4:00–4:30 | Open `/evals/results.md` — show retrieval hit-rate and groundedness numbers from the golden set |
| 4:30–5:00 | "Three things I'd do next: [scale to 10k hours with HNSW + reranking], [the realtime moderator angle], [port to Rails]. Thanks." |

Upload to YouTube unlisted. Link in README.

---

## 9. README outline (for the repo)

```markdown
# Research Copilot
> A mini Great Question — semantic search, evidence-backed Q&A, and evals for customer interviews.

🎥 [3-min demo video](youtube-link)
🌐 [Live demo](vercel-link)
🔌 [MCP server setup](docs/mcp.md)

## Why I built this
Applying for the Great Question AI Engineer Intern role. The JD calls out semantic
search across interview hours, MCP tooling, and evals — so I built a small version
of all three in one app, using real customer interview transcripts.

## What it does
- [feature list with screenshots]

## How it works
- [architecture diagram]
- [retrieval pipeline]
- [eval methodology + current numbers]

## Eval results
Retrieval hit-rate @ k=5: 0.87
Groundedness (LLM-judge avg): 91/100
Citation accuracy: 96%
[Full report](evals/results.md)

## Stack
- [the table from §4]

## Running locally
```bash
bin/setup        # installs gems, sets up DB, runs migrations, seeds 5 transcripts
bin/dev          # starts Rails + esbuild + Tailwind watcher
bin/eval         # runs the golden-set eval and rewrites evals/results.md
```

## What I'd build next
- Scale retrieval to 10k+ hours (HNSW index in pgvector + Cohere rerank)
- Realtime moderator (Deepgram streaming STT + Claude tool-use for follow-up questions)
- Downgrade to Rails 6 to match GQ's prod
- Multi-tenant data isolation (row-level scoping per workspace)
- Replace seed transcripts with a real workspace abstraction
```

---

## 10. Timeline (5–7 days, aggressive — Rails edition)

| Day | Goal |
|---|---|
| 1 | `rails new` w/ Postgres + jsbundling-rails + Tailwind. Add `neighbor` + `pg` for pgvector. `Transcript` + `Chunk` models with vector column. Ingest 1 transcript end-to-end (parse → chunk → embed → store) via SolidQueue job |
| 2 | React UI mounted on a Rails page. Semantic search endpoint + UI showing ranked quotes |
| 3 | Q&A endpoint: retrieve top-k → gpt-4o (JSON mode) w/ context → answer + structured citations. Stream tokens via Turbo Streams |
| 4 | Theme extraction job + groundedness eval (LLM-as-judge). Build the eval harness + golden set, commit `evals/results.md` |
| 5 | Node MCP server in `/mcp-server` calling Rails API. Test with Claude Desktop |
| 6 | Polish UI, pre-load 5 seed interview transcripts, deploy to Fly.io |
| 7 | Record demo video, finish README, submit |

---

## 11. What to *not* do

- ❌ Don't build auth, billing, multi-tenancy, or a settings page
- ❌ Don't use Devise — skip auth entirely, demo runs in a single workspace
- ❌ Don't make it pretty beyond Tailwind defaults + maybe a few headless-ui components
- ❌ Don't fine-tune anything
- ❌ Don't reach for `langchainrb` — write the 30-line retrieval loop yourself, it shows you actually understand RAG
- ❌ Don't use Heroku (paid + slow cold starts) or AWS console clickops — Fly.io has a CLI-first flow that ships in minutes
- ❌ Don't write a 2-page README — they'll skim. The video is the artifact.

---

## 12. The closing line for your application

> "I built Research Copilot — a mini Great Question — because I wanted my demo to engage directly with the problems your team is solving. It ships semantic search over real interview transcripts, MCP tools that Claude can call, and a groundedness eval harness — three of the four areas the JD called out. The demo video is 5 minutes. The live app is at [link]. The code is at [repo]."

That sentence + the artifact does 80% of the work.
