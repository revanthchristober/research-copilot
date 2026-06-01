class AddHnswIndexToChunks < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :chunks, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              algorithm: :concurrently,
              name: "index_chunks_on_embedding_hnsw_cosine"
  end
end
