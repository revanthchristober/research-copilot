class ThemeExtractionJob < ApplicationJob
  queue_as :default

  EXTRACT_MODEL = "gpt-4o-2024-08-06"

  THEMES_SCHEMA = {
    name: "research_themes",
    strict: true,
    schema: {
      type: "object",
      properties: {
        themes: {
          type: "array",
          description: "5-10 recurring themes across the chunks. Each theme is a distinct pain point, request, or pattern.",
          items: {
            type: "object",
            properties: {
              label: { type: "string", description: "Short label, 2-6 words" },
              summary: { type: "string", description: "1-2 sentences describing the theme" },
              supporting_chunk_ids: {
                type: "array",
                description: "chunk_ids of every chunk that supports this theme",
                items: { type: "integer" }
              },
              confidence: {
                type: "number",
                description: "0.0-1.0 confidence this is a real recurring pattern (>= 2 chunks across >= 2 transcripts is high confidence)"
              }
            },
            required: [ "label", "summary", "supporting_chunk_ids", "confidence" ],
            additionalProperties: false
          }
        }
      },
      required: [ "themes" ],
      additionalProperties: false
    }
  }.freeze

  def perform
    chunks = Chunk.embedded.includes(:transcript).to_a
    return if chunks.empty?

    context = chunks.map { |c|
      "[chunk_id=#{c.id}, transcript=\"#{c.transcript.title}\", speaker=#{c.speaker || '—'}]\n#{c.text}"
    }.join("\n\n---\n\n")

    system = <<~SYS.strip
      You are a senior customer research analyst. Identify 5-10 recurring themes across the interview chunks.

      Rules:
        - A theme is a distinct customer pain, request, surprise, or behavior pattern.
        - Each theme MUST cite at least one supporting chunk_id from the provided list.
        - Prefer themes that appear across multiple transcripts (cross-cutting > single-interview).
        - Use short, scannable labels (e.g. "Onboarding navigation pain", "Hidden cost reveal").
        - confidence reflects how cross-cutting the evidence is: 0.9+ if 3+ chunks across 2+ transcripts; 0.5-0.8 if 2 chunks; <0.5 if single chunk.
    SYS

    user = "Interview chunks:\n#{context}\n\nReturn JSON with 5-10 themes."

    payload = LLM.complete_with_schema(
      model: EXTRACT_MODEL,
      schema: THEMES_SCHEMA,
      temperature: 0.3,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user }
      ]
    )

    valid_ids = chunks.map(&:id).to_set

    Theme.transaction do
      Theme.delete_all
      (payload["themes"] || []).each do |t|
        supporting = (t["supporting_chunk_ids"] || []).select { |id| valid_ids.include?(id) }
        next if supporting.empty?
        Theme.create!(
          label: t["label"],
          summary: t["summary"],
          supporting_chunk_ids: supporting,
          evidence_count: supporting.length,
          confidence: t["confidence"]
        )
      end
    end
  end
end
