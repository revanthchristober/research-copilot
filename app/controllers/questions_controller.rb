class QuestionsController < ApplicationController
  before_action :set_question, only: [ :show ]

  def index
    @questions = Question.order(asked_at: :desc).limit(20)
  end

  def new
    @question = Question.new
  end

  def create
    @question = Question.new(question_params)
    @question.asked_at ||= Time.current

    if @question.body.to_s.strip.empty?
      @question.errors.add(:body, "can't be blank")
      return render :new, status: :unprocessable_entity
    end

    if @question.save
      redirect_to question_path(@question)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  private

  def set_question
    @question = Question.find(params[:id])
  end

  def question_params
    params.require(:question).permit(:body)
  end
end
