# Build Plan — Research Copilot
> Phase-by-phase, 7 days, Rails-first. Each phase has a single shippable outcome.

---

## Phase 0 — Environment + skeleton (½ day)
**Outcome:** `bin/dev` starts a blank Rails app at localhost:3000 with Postgres + pgvector connected.

- [ ] Install `mise` (Ruby/tool version manager): `curl https://mise.run | sh`
- [ ] Install Ruby 3.3.6 + Rails 8 + Postgres 16 + pgvector (see [SETUP.md](SETUP.md))
- [ ] `rails new . -d postgresql -j esbuild -c tailwind --skip-test`
- [ ] Add gems: `neighbor`, `anthropic`, `ruby-openai`, `dotenv-rails`, `solid_queue`, `aws-sdk-s3` (anthropic gem stays in Gemfile but unused for now — LLM adapter routes everything to OpenAI)
- [ ] Enable pgvector in `db/migrate/0_enable_pgvector.rb` → `enable_extension "vector"`
- [ ] Create `.env` with `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `R2_*` creds
- [ ] `bin/dev` boots, healthcheck route `/health` returns 200

**Done when:** you can hit `/health` and see "ok", and `rails db:migrate` runs without errors.

---

## Phase 1 — Domain models (½ day)
**Outcome:** Database schema in place. Can create transcripts + chunks via `rails console`.

- [ ] `Transcript` — title, source_type, raw_text, metadata (jsonb), audio_attached (ActiveStorage)
- [ ] `Chunk` — transcript_id, position, speaker, start_ts, end_ts, text, embedding (vector(1536))
- [ ] `Question` — text, asked_at
- [ ] `Answer` — question_id, body, citations (jsonb), groundedness_score, judge_notes
- [ ] `Theme` — label, summary, supporting_chunk_ids (jsonb), confidence
- [ ] Add `has_neighbors :embedding` to Chunk via the `neighbor` gem
- [ ] Seed task `db/seeds.rb` that loads 5 hand-picked interview transcripts from `db/seed_data/*.txt`

**Done when:** `Transcript.count == 5` and `Chunk.count > 100` after `rails db:seed`.

---

## Phase 2 — Ingestion pipeline (1 day)
**Outcome:** Paste a transcript → it chunks, embeds, and stores. End-to-end async.

- [ ] `TranscriptParser` service — handles `.txt`, `.vtt`, `.srt` (3 small classes, one strategy each)
- [ ] `Chunker` service — splits by ~500-token windows w/ 50-token overlap, preserves speaker turns
- [ ] `EmbedChunkJob` — SolidQueue job, calls OpenAI `text-embedding-3-small`, writes vector
- [ ] `IngestTranscriptJob` — orchestrates parse → chunk → enqueue N embed jobs
- [ ] Upload UI — single page with textarea + "Ingest" button + progress (Turbo Stream poll on job status)
- [ ] Show transcript list with chunk count + embedding completion %

**Done when:** pasting a 2-page transcript shows it in the list with all chunks embedded within 30s.

---

## Phase 3 — Semantic search (½ day)
**Outcome:** Type a query, see top-10 ranked quotes with speaker + timestamp.

- [ ] `SearchService` — embeds query, runs pgvector cosine search, returns top-k chunks
- [ ] HNSW index on `chunks.embedding` for speed
- [ ] Search UI — input box + ranked list (chunk text, transcript title, speaker, timestamp, similarity score)
- [ ] Optional: rerank top-20 → top-10 with `gpt-4o-mini` via the LLM adapter (single batched call)
- [ ] Highlight matched terms in results

**Done when:** query "onboarding confusion" returns relevant quotes from multiple transcripts, ordered by relevance.

---

## Phase 4 — Q&A with evidence (1 day)
**Outcome:** Ask a question, stream an answer with inline citations linked to source chunks.

- [ ] `AnswerService` — retrieve top-k, build a prompt that *requires* JSON output: `{ answer, citations: [{chunk_id, quote}] }`
- [ ] Use `gpt-4o` with JSON mode (`response_format: { type: "json_object" }`) to enforce the schema
- [ ] Stream tokens to UI via Turbo Streams + `ActionController::Live`
- [ ] UI: answer body with inline `[1]` `[2]` citations → click opens popover with full quote + transcript link
- [ ] Persist `Question` + `Answer` rows for the eval harness later

**Done when:** asking "What are the top 3 onboarding pain points?" returns a coherent answer with ≥3 distinct citations to real chunks.

---

## Phase 5 — Themes + groundedness eval (1 day)
**Outcome:** Auto-extract recurring themes. Every generated insight has a 0–100 groundedness score. Eval harness committed.

- [ ] `ThemeExtractionJob` — over all chunks, cluster into 5–10 themes with `gpt-4o`, store w/ supporting chunk IDs
- [ ] Themes UI — list of pain points + evidence count + click-through to chunks
- [ ] `GroundednessJudge` service — LLM-as-judge prompt that scores answer/insight against retrieved chunks 0–100, returns reasoning
- [ ] Show score badge next to every answer in the UI
- [ ] Golden eval set: `evals/golden_set.yml` with 10 Q→A pairs + expected source chunks
- [ ] `bin/eval` task — runs golden set, computes retrieval hit-rate @ k=5, groundedness avg, citation accuracy, writes `evals/results.md`
- [ ] Commit the results.md so it's visible in the repo

**Done when:** `bin/eval` runs in < 60s and outputs a markdown report with three numbers.

---

## Phase 6 — MCP server + deploy (1 day)
**Outcome:** Claude Desktop can call your tools to query the research brain. App is live on Fly.io.

- [ ] `/mcp-server` — tiny Node/TS project with `@modelcontextprotocol/sdk`
- [ ] Tools: `search_interviews(query, k)`, `get_quotes(chunk_ids)`, `find_pain_points()`, `find_feature_requests()`, `ask_research_question(question)`
- [ ] Each tool calls the Rails app over HTTP (`http://localhost:3000/api/...`)
- [ ] Add minimal `/api/*` JSON endpoints in Rails (no auth for demo)
- [ ] Test locally: register MCP server in Claude Desktop config, ask a question through Claude
- [ ] `fly launch` — Rails app + Postgres + Volume
- [ ] Production seed: load the 5 transcripts in prod, regenerate embeddings
- [ ] Smoke test the deployed app

**Done when:** live URL works, MCP demo works in Claude Desktop, golden eval passes in prod.

---

## Phase 7 — Demo + submit (½ day)
**Outcome:** Application is sent.

- [ ] Polish UI: empty states, loading states, basic responsive
- [ ] Pre-seed prod with 5 hand-picked transcripts (so reviewer sees data immediately)
- [ ] Record 5-min demo video (script in SPEC.md §8). Upload to YouTube unlisted.
- [ ] Finalize README with: video link, live link, eval numbers, screenshots
- [ ] Polish "Why I'm right for this role" answer (see [APPLICATION_ANSWER.md](APPLICATION_ANSWER.md))
- [ ] Resume PDF ready
- [ ] **Submit** via Great Question's application form

**Done when:** application is sent and you've slept.

---

## Critical-path dependencies

```
P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7
                          ↘
                           (P5 can start after P4 partially done)
```

Themes (P5) and MCP (P6) are the parts where AI assistance accelerates you most because they're prompt-engineering heavy. Phases 1–3 are the parts where Rails idiom familiarity matters most.

---

## Risk register

| Risk | Mitigation |
|---|---|
| Rails learning curve eats Day 1–2 | Use AI to write migrations + models, focus on understanding ActiveRecord queries and SolidQueue job patterns |
| pgvector + neighbor gem quirks | Test with 10 chunks before scaling — catch the embedding dimension mismatch early |
| LLM streaming + Turbo Streams = unfamiliar combo | Fallback: render the full response (no streaming) for the demo. Looks 90% as good. |
| Fly.io Postgres + pgvector not pre-installed | Use Fly's `pgvector` image: `fly pg create --image-ref flyio/postgres-flex:16-with-pgvector` |
| Demo data feels weak | Seed with 5 *real* Lenny's Podcast guest transcripts (Whisper them yourself) — way more interesting than synthetic |

---

## Daily check-in template

Each day, ask yourself:
1. Did I close the phase I was on?
2. What blocked me?
3. Can I cut a stretch goal to stay on the critical path?

The submission deadline is the only thing that matters. Polish < ship.
