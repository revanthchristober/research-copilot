puts "[seeds] clearing existing data..."
Theme.delete_all
Answer.delete_all
Question.delete_all
Chunk.delete_all
Transcript.delete_all

puts "[seeds] creating sample transcript..."

t = Transcript.create!(
  title: "Sample onboarding interview — Acme SaaS",
  source_type: "text",
  status: "pending",
  metadata: { interviewer: "Jane Doe", participant: "Alex (P1)", recorded_at: "2026-05-15" },
  raw_text: <<~TEXT
    Jane: Walk me through the first time you set up an account.
    Alex: Honestly the bank-connection step was the most confusing. I wasn't sure if it was secure.
    Jane: What would have helped?
    Alex: A clearer explanation up front of what data you actually pull. I almost dropped off there.
  TEXT
)

[
  { speaker: "Jane",  start_ts:  0.0, end_ts:  4.5, text: "Walk me through the first time you set up an account." },
  { speaker: "Alex",  start_ts:  4.5, end_ts: 14.0, text: "Honestly the bank-connection step was the most confusing. I wasn't sure if it was secure." },
  { speaker: "Jane",  start_ts: 14.0, end_ts: 17.0, text: "What would have helped?" },
  { speaker: "Alex",  start_ts: 17.0, end_ts: 27.0, text: "A clearer explanation up front of what data you actually pull. I almost dropped off there." }
].each_with_index do |row, i|
  t.chunks.create!(
    position: i,
    speaker: row[:speaker],
    start_ts: row[:start_ts],
    end_ts: row[:end_ts],
    text: row[:text]
  )
end

puts "[seeds] done: #{Transcript.count} transcript, #{Chunk.count} chunks (no embeddings yet — that's Phase 2)"
