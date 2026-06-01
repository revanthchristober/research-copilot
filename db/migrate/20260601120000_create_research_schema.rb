class CreateResearchSchema < ActiveRecord::Migration[8.0]
  def change
    enable_extension "vector" unless extension_enabled?("vector")

    create_table :transcripts do |t|
      t.string :title, null: false
      t.string :source_type, default: "text", null: false
      t.text :raw_text
      t.jsonb :metadata, default: {}, null: false
      t.string :status, default: "pending", null: false
      t.timestamps
    end
    add_index :transcripts, :status

    create_table :chunks do |t|
      t.references :transcript, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :speaker
      t.float :start_ts
      t.float :end_ts
      t.text :text, null: false
      t.column :embedding, "vector(1536)"
      t.integer :token_count
      t.timestamps
    end
    add_index :chunks, [ :transcript_id, :position ], unique: true

    create_table :questions do |t|
      t.text :body, null: false
      t.datetime :asked_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end

    create_table :answers do |t|
      t.references :question, null: false, foreign_key: { on_delete: :cascade }
      t.text :body, null: false
      t.jsonb :citations, default: [], null: false
      t.integer :groundedness_score
      t.text :judge_notes
      t.string :model_used
      t.timestamps
    end

    create_table :themes do |t|
      t.string :label, null: false
      t.text :summary
      t.jsonb :supporting_chunk_ids, default: [], null: false
      t.integer :evidence_count, default: 0, null: false
      t.float :confidence
      t.timestamps
    end
    add_index :themes, :evidence_count
  end
end
