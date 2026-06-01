class Transcript < ApplicationRecord
  STATUSES = %w[pending ingesting embedded failed].freeze

  has_many :chunks, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :ready, -> { where(status: "embedded") }

  def fully_embedded?
    chunks.any? && chunks.where(embedding: nil).none?
  end

  def embedding_progress
    total = chunks.count
    return 0 if total.zero?
    done = chunks.where.not(embedding: nil).count
    (done.to_f / total * 100).round(1)
  end
end
