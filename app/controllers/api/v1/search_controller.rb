module Api
  module V1
    class SearchController < BaseController
      def index
        q = params[:q].to_s.strip
        k = (params[:k] || 10).to_i.clamp(1, 50)

        if q.empty?
          render json: { query: q, results: [] } and return
        end

        results = SearchService.call(query: q, k: k, rerank: false)

        render json: {
          query: q,
          count: results.length,
          results: results.map { |r|
            {
              chunk_id: r.chunk.id,
              transcript_id: r.transcript.id,
              transcript_title: r.transcript_title,
              speaker: r.speaker,
              timestamp: r.display_timestamp,
              text: r.text,
              similarity: r.similarity
            }
          }
        }
      end

      # POST /api/v1/quotes  body: { chunk_ids: [1, 2, ...] }
      def quotes
        ids = Array(params[:chunk_ids]).map(&:to_i).first(50)
        chunks = Chunk.where(id: ids).includes(:transcript)
        render json: {
          quotes: chunks.map { |c|
            {
              chunk_id: c.id,
              transcript_id: c.transcript.id,
              transcript_title: c.transcript.title,
              speaker: c.speaker,
              timestamp: c.display_timestamp,
              text: c.text
            }
          }
        }
      end
    end
  end
end
