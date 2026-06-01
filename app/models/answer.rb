class Answer < ApplicationRecord
  belongs_to :question

  validates :body, presence: true

  def cited_chunk_ids
    citations.map { |c| c["chunk_id"] }.compact
  end

  def cited_chunks
    Chunk.where(id: cited_chunk_ids)
  end
end
