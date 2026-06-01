# Setup — get to `bin/dev` in 30 minutes
> macOS arm64 (Apple Silicon). One-time setup before Phase 1.

## 1. Install mise (Ruby + tool version manager)

```bash
curl https://mise.run | sh
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
exec zsh
```

## 2. Install Ruby 3.3.6 via mise

```bash
cd /Users/home/PROJECTS/great-ques-ai-researcher
mise use ruby@3.3.6
ruby -v   # should print 3.3.6
```

This pins Ruby for this project only (writes `.mise.toml`).

## 3. Install Rails 8

```bash
gem install rails -v 8.0.1
gem install bundler
rails -v   # should print Rails 8.0.x
```

## 4. Install Postgres 16 + pgvector locally

```bash
brew install postgresql@16 pgvector
brew services start postgresql@16
createdb research_copilot_development
createdb research_copilot_test
```

Verify pgvector is loadable:
```bash
psql research_copilot_development -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

## 5. Get API keys

| Service | Where | What you need |
|---|---|---|
| Anthropic | console.anthropic.com | `ANTHROPIC_API_KEY` (~$5 credit is plenty for 7 days) |
| OpenAI | platform.openai.com | `OPENAI_API_KEY` (~$2 for embeddings) |
| Cloudflare R2 | dash.cloudflare.com → R2 | `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ENDPOINT` |
| Fly.io | fly.io | `flyctl auth login` (already installed ✅) |
| Deepgram (stretch) | console.deepgram.com | `DEEPGRAM_API_KEY` (free tier ok) |

## 6. Generate the Rails app

```bash
cd /Users/home/PROJECTS/great-ques-ai-researcher
rails new . -d postgresql -j esbuild -c tailwind --skip-test --force
```

The `--force` is needed because SPEC.md / PHASES.md already exist in this dir. Rails will skip them.

## 7. Add the project gems

In `Gemfile`, add:
```ruby
gem "neighbor"               # pgvector for ActiveRecord
gem "ruby-anthropic"         # Claude API
gem "ruby-openai"            # OpenAI embeddings
gem "dotenv-rails"           # .env file loader
gem "aws-sdk-s3"             # Cloudflare R2 (S3-compatible)
```

Then:
```bash
bundle install
bin/rails db:create
bin/rails generate solid_queue:install
bin/rails db:migrate
```

## 8. `.env` template

Create `.env` in repo root:
```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=research-copilot
R2_ENDPOINT=https://<account>.r2.cloudflarestorage.com
```

Add `.env` to `.gitignore` immediately.

## 9. Verify the stack

```bash
bin/dev
```

Then in another terminal:
```bash
curl http://localhost:3000   # should return the Rails welcome page
```

## 10. Sanity-check pgvector + Anthropic

```bash
bin/rails console
```

```ruby
ActiveRecord::Base.connection.execute("SELECT '[1,2,3]'::vector;").to_a
# => [{"vector"=>"[1,2,3]"}]

require "anthropic"
client = Anthropic::Client.new(access_token: ENV["ANTHROPIC_API_KEY"])
client.messages(parameters: {
  model: "claude-sonnet-4-6",
  max_tokens: 50,
  messages: [{ role: "user", content: "Say hi in 3 words" }]
})
# => should return a response with "Hi there friend" or similar
```

If both work, you're ready for Phase 1.
