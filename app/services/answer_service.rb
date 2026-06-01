class AnswerService
  RETRIEVAL_K = 8
  MODEL = "gpt-4o-2024-08-06"

  ANSWER_SCHEMA = {
    name: "research_answer",
    strict: true,
    schema: {
      type: "object",
      properties: {
        answer: {
          type: "string",
          description: "A concise, evidence-grounded answer to the research question. Use [N] markers to reference the chunks. Don't fabricate."
        },
        citations: {
          type: "array",
          description: "The chunks you actually used. Each cite must point to a chunk_id from the retrieved set.",
          items: {
            type: "object",
            properties: {
              chunk_id: { type: "integer" },
              quote: {
                type: "string",
                description: "An exact, short verbatim quote (under 200 chars) from that chunk supporting the claim."
              }
            },
            required: [ "chunk_id", "quote" ],
            additionalProperties: false
          }
        }
      },
      required: [ "answer", "citations" ],
      additionalProperties: false
    }
  }.freeze

  def self.call(question:)
    new(question: question).call
  end

  def initialize(question:)
    @question = question
  end

  def call
    chunks = retrieve
    if chunks.empty?
      return persist_empty_answer!
    end

    payload = ask_llm(chunks)
    payload = sanitize_citations(payload, chunks)
    answer = persist_answer!(payload, chunks)
    judge!(answer, chunks)
    answer
  end

  private

  def retrieve
    Chunk.embedded
         .nearest_neighbors(:embedding, LLM.embed(@question.body), distance: "cosine")
         .includes(:transcript)
         .limit(RETRIEVAL_K)
         .to_a
  end

  def ask_llm(chunks)
    context = chunks.each_with_index.map { |c, i|
      "[chunk_id=#{c.id}, transcript=\"#{c.transcript.title}\", speaker=#{c.speaker || '—'}]\n#{c.text}"
    }.join("\n\n---\n\n")

    system = <<~SYS.strip
      You are a customer research analyst. Answer STRICTLY based on the retrieved interview chunks.

      Output rules:
        - Use [N] markers inline in the answer. N is 1-indexed and matches the position in the
          `citations` array. EVERY [N] in the prose must have a corresponding citations entry.
          The number of [N] markers and the number of citations entries MUST be equal.
        - When the question is "top N", "patterns", "themes", or any plural enumeration: produce
          N distinct numbered points in the prose, each ending with its own [K] citation.
        - Two citations MAY point to the same chunk_id if they highlight different sub-themes in
          that chunk — use different quotes in that case.
        - If fewer than N distinct points are supported by the chunks, state that explicitly and
          provide only what the evidence supports.
        - Quotes must be exact verbatim substrings of the cited chunk's text.
        - Never fabricate.
    SYS

    user = <<~USER.strip
      Research question:
      #{@question.body}

      Retrieved interview chunks (each prefixed with its chunk_id):
      #{context}

      Return JSON matching the schema. The answer should be 2-6 sentences with [N] inline markers.
      Cite EVERY chunk you actually reference. Aim for at least 3 distinct chunks when the question
      invites a multi-point answer.
    USER

    LLM.complete_with_schema(
      model: MODEL,
      schema: ANSWER_SCHEMA,
      temperature: 0.4,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user }
      ]
    )
  end

  def sanitize_citations(payload, chunks)
    valid_ids = chunks.map(&:id).to_set
    payload["citations"] = (payload["citations"] || []).select { |c|
      valid_ids.include?(c["chunk_id"])
    }
    payload
  end

  def persist_answer!(payload, retrieved)
    Answer.create!(
      question: @question,
      body: payload.fetch("answer"),
      citations: payload.fetch("citations"),
      model_used: MODEL
    )
  end

  def persist_empty_answer!
    Answer.create!(
      question: @question,
      body: "I couldn't find any relevant interview content for this question. Try ingesting more transcripts first.",
      citations: [],
      model_used: MODEL
    )
  end

  def judge!(answer, chunks)
    cited_chunks = chunks.select { |c| answer.cited_chunk_ids.include?(c.id) }
    verdict = GroundednessJudge.score(answer: answer, chunks: cited_chunks.any? ? cited_chunks : chunks)
    answer.update!(
      groundedness_score: verdict["score"],
      judge_notes: verdict.except("score").to_json
    )
  rescue => e
    Rails.logger.warn("Judging failed for answer #{answer.id}: #{e.class}: #{e.message}")
  end
end
