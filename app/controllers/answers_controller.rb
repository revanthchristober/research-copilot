class AnswersController < ApplicationController
  def show
    @question = Question.find(params[:question_id])
    @answer = @question.latest_answer || AnswerService.call(question: @question)
    render partial: "answers/answer", locals: { question: @question, answer: @answer }
  end
end
