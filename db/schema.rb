# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_06_01_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "answers", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.text "body", null: false
    t.jsonb "citations", default: [], null: false
    t.integer "groundedness_score"
    t.text "judge_notes"
    t.string "model_used"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_answers_on_question_id"
  end

  create_table "chunks", force: :cascade do |t|
    t.bigint "transcript_id", null: false
    t.integer "position", null: false
    t.string "speaker"
    t.float "start_ts"
    t.float "end_ts"
    t.text "text", null: false
    t.vector "embedding", limit: 1536
    t.integer "token_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_chunks_on_embedding_hnsw_cosine", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["transcript_id", "position"], name: "index_chunks_on_transcript_id_and_position", unique: true
    t.index ["transcript_id"], name: "index_chunks_on_transcript_id"
  end

  create_table "questions", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "asked_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "themes", force: :cascade do |t|
    t.string "label", null: false
    t.text "summary"
    t.jsonb "supporting_chunk_ids", default: [], null: false
    t.integer "evidence_count", default: 0, null: false
    t.float "confidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["evidence_count"], name: "index_themes_on_evidence_count"
  end

  create_table "transcripts", force: :cascade do |t|
    t.string "title", null: false
    t.string "source_type", default: "text", null: false
    t.text "raw_text"
    t.jsonb "metadata", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_transcripts_on_status"
  end

  add_foreign_key "answers", "questions", on_delete: :cascade
  add_foreign_key "chunks", "transcripts", on_delete: :cascade
end
