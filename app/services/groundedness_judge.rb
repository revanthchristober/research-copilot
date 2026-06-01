class GroundednessJudge
  JUDGE_MODEL = "gpt-4o-mini"

  JUDGE_SCHEMA = {
    name: "groundedness_verdict",
    strict: true,
    schema: {
      type: "object",
      properties: {
        score: {
          type: "integer",
          description: "0-100. 100 = every claim in the answer is directly supported by the provided chunks. 0 = the answer is entirely unsupported or fabricated."
        },
        reasoning: {
          type: "string",
          description: "1-3 sentences explaining the score, naming specific unsupported claims if any."
        },
        unsupported_claims: {
          type: "array",
          description: "List of any specific claims in the answer that are NOT supported by the chunks. Empty if fully grounded.",
          items: { type: "string" }
        }
      },
      required: [ "score", "reasoning", "unsupported_claims" ],
      additionalProperties: false
    }
  }.freeze

  def self.score(answer:, chunks:)
    new(answer: answer, chunks: chunks).score
  end

  def initialize(answer:, chunks:)
    @answer = answer
    @chunks = chunks
  end

  def score
    return empty_verdict if @chunks.empty?

    context = @chunks.each_with_index.map { |c, i|
      "[chunk_id=#{c.id}] #{c.text}"
    }.join("\n\n---\n\n")

    system = <<~SYS.strip
      You are a strict groundedness judge for a customer research RAG system.

      Your job: decide whether every factual claim in the ANSWER is directly supported
      by the provided CHUNKS. Be skeptical — penalize claims that paraphrase, generalize,
      or add information not literally present in the chunks.

      Scoring rubric (0-100):
        90-100: Every claim is directly traceable to a specific quote in a chunk.
        70-89:  Mostly grounded, but one or two minor paraphrases or unsupported framings.
        40-69:  Significant unsupported claims or generalizations beyond the chunks.
        0-39:   Major fabrication, claims with no basis in the chunks, or hallucinated entities.

      Ignore: writing style, citation marker formatting, completeness. Only judge groundedness.
    SYS

    user = <<~USER.strip
      CHUNKS:
      #{context}

      ANSWER (to be judged):
      #{@answer.is_a?(Answer) ? @answer.body : @answer}

      Return JSON matching the schema.
    USER

    LLM.complete_with_schema(
      model: JUDGE_MODEL,
      schema: JUDGE_SCHEMA,
      temperature: 0,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user }
      ]
    )
  rescue => e
    Rails.logger.warn("GroundednessJudge failed: #{e.class}: #{e.message}")
    { "score" => nil, "reasoning" => "judge failed: #{e.message[0..120]}", "unsupported_claims" => [] }
  end

  private

  def empty_verdict
    { "score" => 0, "reasoning" => "No chunks provided to judge against.", "unsupported_claims" => [] }
  end
end
