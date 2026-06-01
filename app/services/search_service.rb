class SearchService
  Result = Struct.new(:chunk, :similarity, :rerank_score, keyword_init: true) do
    delegate :id, :text, :speaker, :start_ts, :end_ts, :display_timestamp, :transcript, to: :chunk
    def transcript_title = transcript.title
    def score = rerank_score || similarity
  end

  DEFAULT_K = 10
  RERANK_CANDIDATES = 20

  def self.call(query:, k: DEFAULT_K, rerank: false)
    new(query: query, k: k, rerank: rerank).call
  end

  def initialize(query:, k:, rerank:)
    @query = query.to_s.strip
    @k = k
    @rerank = rerank
  end

  def call
    return [] if @query.empty?

    candidates = retrieve(@rerank ? RERANK_CANDIDATES : @k)
    @rerank ? rerank(candidates).first(@k) : candidates
  end

  private

  def retrieve(limit)
    vec = LLM.embed(@query)
    chunks = Chunk.embedded
                  .nearest_neighbors(:embedding, vec, distance: "cosine")
                  .includes(:transcript)
                  .limit(limit)
                  .to_a

    chunks.map do |c|
      Result.new(chunk: c, similarity: cosine_similarity(c))
    end
  end

  def cosine_similarity(chunk)
    return nil unless chunk.respond_to?(:neighbor_distance) && chunk.neighbor_distance
    (1.0 - chunk.neighbor_distance).round(4)
  end

  def rerank(results)
    return results if results.length <= 1

    docs = results.each_with_index.map { |r, i| { index: i, text: r.chunk.text[0..400] } }

    prompt = <<~PROMPT
      You are ranking search results by relevance to a research query.

      Query: #{@query}

      For each candidate, score relevance from 0 to 100 (100 = perfect match).
      Reply ONLY with JSON in this exact shape:
      {"scores": [{"index": 0, "score": 87}, ...]}

      Candidates:
      #{docs.map { |d| "[#{d[:index]}] #{d[:text]}" }.join("\n\n")}
    PROMPT

    response = LLM.complete_json(
      model: LLM::CHEAP_MODEL,
      messages: [ { role: "user", content: prompt } ]
    )

    scores = response.fetch("scores", []).index_by { |s| s["index"] }
    results.each_with_index { |r, i| r.rerank_score = (scores.dig(i, "score") || 0).to_f / 100 }
    results.sort_by { |r| -r.rerank_score }
  rescue => e
    Rails.logger.warn("Rerank failed, falling back to vector order: #{e.class}: #{e.message}")
    results
  end
end
