module Api
  module V1
    class ThemesController < BaseController
      def index
        themes = Theme.order(evidence_count: :desc, confidence: :desc)
        render json: {
          count: themes.length,
          themes: themes.map { |t|
            {
              id: t.id,
              label: t.label,
              summary: t.summary,
              evidence_count: t.evidence_count,
              confidence: t.confidence,
              supporting_chunk_ids: t.supporting_chunk_ids
            }
          }
        }
      end

      def create
        ThemeExtractionJob.perform_now
        themes = Theme.order(evidence_count: :desc, confidence: :desc)
        render json: {
          status: "extracted",
          count: themes.length,
          themes: themes.map { |t| { id: t.id, label: t.label, evidence_count: t.evidence_count } }
        }
      end
    end
  end
end
