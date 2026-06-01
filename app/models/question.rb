class Question < ApplicationRecord
  has_many :answers, dependent: :destroy

  validates :body, presence: true

  def latest_answer
    answers.order(created_at: :desc).first
  end
end
