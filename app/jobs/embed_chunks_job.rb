class EmbedChunksJob < ApplicationJob
  queue_as :default

  retry_on OpenAI::Error,            wait: :polynomially_longer, attempts: 5 if defined?(OpenAI::Error)
  retry_on Faraday::TimeoutError,    wait: :polynomially_longer, attempts: 5
  retry_on Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 5

  def perform(chunk_ids)
    chunks = Chunk.where(id: chunk_ids).order(:id).to_a
    return if chunks.empty?

    embeddings = LLM.embed_many(chunks.map(&:text))

    Chunk.transaction do
      chunks.zip(embeddings).each do |chunk, vec|
        chunk.update!(embedding: vec)
      end
    end

    broadcast_progress(chunks.first.transcript)
  end

  private

  def broadcast_progress(transcript)
    transcript.reload
    if transcript.fully_embedded? && transcript.status != "embedded"
      transcript.update!(status: "embedded")
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      transcript,
      target: "transcript_#{transcript.id}",
      partial: "transcripts/transcript",
      locals: { transcript: transcript }
    )
  end
end
