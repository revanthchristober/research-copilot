class Theme < ApplicationRecord
  validates :label, presence: true

  def supporting_chunks
    Chunk.where(id: supporting_chunk_ids)
  end
end
