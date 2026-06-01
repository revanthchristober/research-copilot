class ThemesController < ApplicationController
  def index
    @themes = Theme.order(evidence_count: :desc, confidence: :desc)
  end

  def create
    ThemeExtractionJob.perform_now
    redirect_to themes_path, notice: "Themes re-extracted."
  end
end
