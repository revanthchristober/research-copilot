class TranscriptParser
  Turn = Struct.new(:speaker, :start_ts, :end_ts, :text, keyword_init: true)

  class << self
    def parse(raw_text:, format: :auto)
      format = detect(raw_text) if format == :auto
      case format
      when :vtt then VTT.new(raw_text).parse
      when :srt then SRT.new(raw_text).parse
      else           Plain.new(raw_text).parse
      end
    end

    def detect(raw)
      first = raw.lstrip.lines.first.to_s.strip
      return :vtt if first == "WEBVTT"
      return :srt if raw =~ /^\d+\s*\n\d\d:\d\d:\d\d[,.]\d{3}\s*-->/
      :plain
    end
  end

  class Plain
    SPEAKER_RE = /^([A-Z][A-Za-z0-9 .'\-]{0,30}):\s+(.+)$/

    def initialize(raw); @raw = raw; end

    def parse
      turns = []
      current = nil
      @raw.each_line do |line|
        line = line.strip
        next if line.empty?
        if (m = line.match(SPEAKER_RE))
          turns << current if current
          current = Turn.new(speaker: m[1].strip, start_ts: nil, end_ts: nil, text: m[2])
        elsif current
          current[:text] += " #{line}"
        else
          current = Turn.new(speaker: nil, start_ts: nil, end_ts: nil, text: line)
        end
      end
      turns << current if current
      turns
    end
  end

  class VTT
    BLOCK = /(?:(?<speaker>[^\n]+?)\n)?(?<start>\d\d:\d\d:\d\d\.\d{3})\s*-->\s*(?<end>\d\d:\d\d:\d\d\.\d{3})[^\n]*\n(?<text>(?:[^\n]+\n?)+)/

    def initialize(raw); @raw = raw.sub(/\AWEBVTT.*?\n\n/m, ""); end

    def parse
      @raw.scan(BLOCK).map do |speaker, start_ts, end_ts, text|
        body = text.strip
        sp, body = extract_inline_speaker(body) if speaker.nil?
        Turn.new(
          speaker: (speaker || sp)&.strip,
          start_ts: to_seconds(start_ts),
          end_ts: to_seconds(end_ts),
          text: body.gsub(/\s+/, " ").strip
        )
      end
    end

    private

    def extract_inline_speaker(text)
      if (m = text.match(/^([A-Z][^:]{0,30}):\s+(.+)/m))
        [ m[1], m[2] ]
      else
        [ nil, text ]
      end
    end

    def to_seconds(ts)
      h, m, s = ts.split(":")
      h.to_i * 3600 + m.to_i * 60 + s.to_f
    end
  end

  class SRT
    BLOCK = /(?<idx>\d+)\s*\n(?<start>\d\d:\d\d:\d\d[,.]\d{3})\s*-->\s*(?<end>\d\d:\d\d:\d\d[,.]\d{3})\s*\n(?<text>(?:.+\n?)+?)(?:\n\n|\z)/

    def initialize(raw); @raw = raw; end

    def parse
      @raw.scan(BLOCK).map do |_idx, start_ts, end_ts, text|
        speaker, body = extract_inline_speaker(text.strip)
        Turn.new(
          speaker: speaker&.strip,
          start_ts: to_seconds(start_ts),
          end_ts: to_seconds(end_ts),
          text: body.gsub(/\s+/, " ").strip
        )
      end
    end

    private

    def extract_inline_speaker(text)
      if (m = text.match(/^([A-Z][^:]{0,30}):\s+(.+)/m))
        [ m[1], m[2] ]
      else
        [ nil, text ]
      end
    end

    def to_seconds(ts)
      h, m, s = ts.tr(",", ".").split(":")
      h.to_i * 3600 + m.to_i * 60 + s.to_f
    end
  end
end
