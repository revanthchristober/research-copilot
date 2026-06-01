namespace :eval do
  desc "Run the golden-set evaluation and write evals/results.md"
  task run: :environment do
    require "yaml"

    Rails.logger.level = :warn
    started_at = Time.current

    golden_path = Rails.root.join("evals/golden_set.yml")
    results_path = Rails.root.join("evals/results.md")
    golden = YAML.load_file(golden_path)
    abort "golden_set.yml is empty" if golden.blank?

    puts "Running eval over #{golden.length} golden questions (parallel, max 5 concurrent)..."

    # Bound concurrency so we don't exhaust the AR connection pool or OpenAI rate limit.
    semaphore = Concurrent::Semaphore.new(5)
    rows = Array.new(golden.length)

    threads = golden.each_with_index.map do |gold, i|
      Thread.new do
        semaphore.acquire
        ActiveRecord::Base.connection_pool.with_connection do
          question_text = gold.fetch("question")
          expected = Array(gold["expected_snippets"]).map { |s| s.to_s.strip }

          retrieved = Chunk.embedded
                          .nearest_neighbors(:embedding, LLM.embed(question_text), distance: "cosine")
                          .includes(:transcript)
                          .limit(5)
                          .to_a

          hit = expected.any? { |snippet| retrieved.any? { |c| c.text.to_s.include?(snippet) } }

          question = Question.create!(body: question_text, asked_at: Time.current)
          answer = AnswerService.call(question: question)

          cited = answer.citations.map { |c|
            chunk = Chunk.find_by(id: c["chunk_id"])
            next [ false ] unless chunk
            [ chunk.text.to_s.include?(c["quote"].to_s.strip) ]
          }
          citation_total = cited.length
          citation_correct = cited.count { |valid, *| valid }

          rows[i] = {
            idx: i + 1,
            question: question_text,
            hit: hit,
            groundedness: answer.groundedness_score,
            citation_total: citation_total,
            citation_correct: citation_correct,
            answer_id: answer.id
          }
          flag = hit ? "✓" : "✗"
          cite_str = citation_total.zero? ? "0/0" : "#{citation_correct}/#{citation_total}"
          g = answer.groundedness_score
          puts "  [#{i + 1}/#{golden.length}] hit=#{flag}  ground=#{g.to_s.rjust(3)}  cite=#{cite_str}  | #{question_text[0..50]}"
        end
      ensure
        semaphore.release
      end
    end
    threads.each(&:join)

    hit_rate = rows.count { |r| r[:hit] }.to_f / rows.length
    grounded = rows.map { |r| r[:groundedness] }.compact
    groundedness_avg = grounded.empty? ? 0 : grounded.sum.to_f / grounded.length
    all_citation_total = rows.sum { |r| r[:citation_total] }
    all_citation_correct = rows.sum { |r| r[:citation_correct] }
    citation_accuracy = all_citation_total.zero? ? 0.0 : all_citation_correct.to_f / all_citation_total

    elapsed = (Time.current - started_at).round(1)

    md = +""
    md << "# Eval results — Research Copilot\n\n"
    md << "_Generated: #{Time.current.utc.iso8601}_  \n"
    md << "_Runtime: #{elapsed}s over #{rows.length} golden questions_\n\n"
    md << "## Headline numbers\n\n"
    md << "| Metric | Value |\n|---|---|\n"
    md << "| Retrieval hit-rate @ k=5 | **#{(hit_rate * 100).round(1)}%** |\n"
    md << "| Groundedness (gpt-4o-mini judge) avg | **#{groundedness_avg.round(1)}/100** |\n"
    md << "| Citation accuracy (verbatim quote match) | **#{(citation_accuracy * 100).round(1)}%** (#{all_citation_correct}/#{all_citation_total}) |\n\n"
    md << "## Per-question detail\n\n"
    md << "| # | Question | Hit@5 | Groundedness | Citations (correct/total) |\n"
    md << "|---|---|---|---|---|\n"
    rows.each do |r|
      cite_disp = r[:citation_total].zero? ? "0/0" : "#{r[:citation_correct]}/#{r[:citation_total]}"
      md << "| #{r[:idx]} | #{r[:question]} | #{r[:hit] ? '✅' : '❌'} | #{r[:groundedness] || '—'}/100 | #{cite_disp} |\n"
    end
    md << "\n## Methodology\n\n"
    md << "- **Retrieval hit-rate @ k=5**: fraction of golden questions where at least one expected\n"
    md << "  snippet (verbatim substring) appears in the top-5 chunks returned by pgvector cosine search.\n"
    md << "- **Groundedness**: a separate gpt-4o-mini call scores each answer 0-100 against the chunks\n"
    md << "  it cited, penalizing any unsupported claim. The judge is not the same model that generated\n"
    md << "  the answer, reducing self-confirmation bias.\n"
    md << "- **Citation accuracy**: fraction of citations across all answers where the cited `quote`\n"
    md << "  is a verbatim substring of the cited chunk's text. Hallucinated quotes fail this check.\n"
    md << "- Golden set lives in [`evals/golden_set.yml`](golden_set.yml).\n"

    File.write(results_path, md)
    puts ""
    puts "─" * 60
    puts "Retrieval hit-rate @ k=5:   #{(hit_rate * 100).round(1)}%"
    puts "Groundedness avg:          #{groundedness_avg.round(1)}/100"
    puts "Citation accuracy:         #{(citation_accuracy * 100).round(1)}% (#{all_citation_correct}/#{all_citation_total})"
    puts "Runtime:                   #{elapsed}s"
    puts "─" * 60
    puts "Report written to #{results_path}"
  end
end
