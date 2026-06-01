module Api
  module V1
    class QuestionsController < BaseController
      # POST /api/v1/ask  body: { question: "..." }
      def ask
        body = params[:question].to_s.strip
        raise ArgumentError, "question is required" if body.empty?

        question = Question.create!(body: body, asked_at: Time.current)
        answer = AnswerService.call(question: question)

        render json: {
          question_id: question.id,
          answer: answer.body,
          groundedness_score: answer.groundedness_score,
          citations: answer.citations.map { |c|
            chunk = Chunk.find_by(id: c["chunk_id"])
            next unless chunk
            {
              chunk_id: c["chunk_id"],
              quote: c["quote"],
              transcript_id: chunk.transcript_id,
              transcript_title: chunk.transcript.title,
              speaker: chunk.speaker
            }
          }.compact,
          model_used: answer.model_used
        }
      end
    end
  end
end
