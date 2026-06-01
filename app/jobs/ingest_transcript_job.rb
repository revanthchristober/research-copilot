class IngestTranscriptJob < ApplicationJob
  queue_as :default

  EMBED_BATCH_SIZE = 25

  def perform(transcript_id)
    transcript = Transcript.find(transcript_id)
    transcript.update!(status: "ingesting")

    turns  = TranscriptParser.parse(raw_text: transcript.raw_text)
    pieces = Chunker.new(turns).call

    Chunk.transaction do
      transcript.chunks.delete_all
      pieces.each do |p|
        transcript.chunks.create!(
          position: p.position,
          speaker: p.speaker,
          start_ts: p.start_ts,
          end_ts: p.end_ts,
          text: p.text,
          token_count: p.token_count
        )
      end
    end

    broadcast_status(transcript)

    transcript.chunks.pending_embedding.pluck(:id).each_slice(EMBED_BATCH_SIZE) do |batch|
      EmbedChunksJob.perform_later(batch)
    end
  rescue => e
    transcript&.update(status: "failed", metadata: transcript.metadata.merge(error: e.message))
    raise
  end

  private

  def broadcast_status(transcript)
    Turbo::StreamsChannel.broadcast_replace_to(
      transcript,
      target: "transcript_#{transcript.id}",
      partial: "transcripts/transcript",
      locals: { transcript: transcript }
    )
  end
end
