class TranscriptsController < ApplicationController
  before_action :set_transcript, only: [ :show ]

  def index
    @transcripts = Transcript.order(created_at: :desc)
  end

  def new
    @transcript = Transcript.new
  end

  def create
    @transcript = Transcript.new(transcript_params.merge(status: "pending"))

    if @transcript.raw_text.to_s.strip.empty?
      @transcript.errors.add(:raw_text, "can't be blank")
      return render :new, status: :unprocessable_entity
    end

    if @transcript.save
      IngestTranscriptJob.perform_later(@transcript.id)
      redirect_to transcripts_path, notice: "Transcript queued for ingestion."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  private

  def set_transcript
    @transcript = Transcript.find(params[:id])
  end

  def transcript_params
    params.require(:transcript).permit(:title, :raw_text)
  end
end
