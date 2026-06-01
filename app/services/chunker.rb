class Chunker
  Chunk = Struct.new(:position, :speaker, :start_ts, :end_ts, :text, :token_count, keyword_init: true)

  TARGET_TOKENS = 500
  OVERLAP_TOKENS = 50
  TOKENS_PER_WORD = 1.3

  def initialize(turns, target: TARGET_TOKENS, overlap: OVERLAP_TOKENS)
    @turns = turns
    @target = target
    @overlap = overlap
  end

  def call
    chunks = []
    buffer = []
    buffer_tokens = 0

    @turns.each do |turn|
      turn_tokens = estimate_tokens(turn.text)

      if turn_tokens >= @target
        flush!(buffer, chunks)
        buffer = []
        buffer_tokens = 0
        split_long_turn(turn).each { |c| chunks << c }
        next
      end

      if buffer_tokens + turn_tokens > @target && buffer.any?
        flush!(buffer, chunks)
        buffer = carry_overlap(buffer)
        buffer_tokens = buffer.sum { |t| estimate_tokens(t.text) }
      end

      buffer << turn
      buffer_tokens += turn_tokens
    end

    flush!(buffer, chunks) if buffer.any?
    chunks.each_with_index { |c, i| c.position = i }
    chunks
  end

  private

  def estimate_tokens(text)
    (text.to_s.split.length * TOKENS_PER_WORD).ceil
  end

  def flush!(buffer, chunks)
    return if buffer.empty?
    chunks << Chunk.new(
      position: nil,
      speaker: dominant_speaker(buffer),
      start_ts: buffer.first.start_ts,
      end_ts: buffer.last.end_ts,
      text: buffer.map { |t| t.speaker ? "#{t.speaker}: #{t.text}" : t.text }.join("\n"),
      token_count: buffer.sum { |t| estimate_tokens(t.text) }
    )
  end

  def dominant_speaker(buffer)
    counts = buffer.group_by(&:speaker).transform_values(&:length)
    counts.max_by { |_, v| v }&.first
  end

  def carry_overlap(buffer)
    rolling = 0
    buffer.reverse.take_while { |t|
      rolling += estimate_tokens(t.text)
      rolling <= @overlap
    }.reverse
  end

  def split_long_turn(turn)
    words = turn.text.split
    chunk_words = (@target / TOKENS_PER_WORD).floor
    overlap_words = (@overlap / TOKENS_PER_WORD).floor

    pieces = []
    i = 0
    while i < words.length
      slice = words[i...(i + chunk_words)]
      pieces << Chunk.new(
        position: nil,
        speaker: turn.speaker,
        start_ts: turn.start_ts,
        end_ts: turn.end_ts,
        text: (turn.speaker ? "#{turn.speaker}: " : "") + slice.join(" "),
        token_count: estimate_tokens(slice.join(" "))
      )
      i += chunk_words - overlap_words
    end
    pieces
  end
end
