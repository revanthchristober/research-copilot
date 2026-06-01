class Chunk < ApplicationRecord
  belongs_to :transcript

  has_neighbors :embedding

  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :transcript_id }
  validates :text, presence: true

  scope :embedded, -> { where.not(embedding: nil) }
  scope :pending_embedding, -> { where(embedding: nil) }

  def display_timestamp
    return nil unless start_ts
    "%02d:%02d" % [ start_ts.to_i / 60, start_ts.to_i % 60 ]
  end
end
