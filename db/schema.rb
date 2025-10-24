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

ActiveRecord::Schema[8.1].define(version: 2025_10_24_003223) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cameras", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "agent_dvr_oid"
    t.integer "capture_interval_seconds", default: 5, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "rtsp_url", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_cameras_on_active"
  end

  create_table "conversation_memories", force: :cascade do |t|
    t.text "answer"
    t.datetime "asked_at"
    t.bigint "camera_id", null: false
    t.integer "confidence_in_answer"
    t.jsonb "context_used"
    t.datetime "created_at", null: false
    t.text "images_analyzed", default: [], array: true
    t.text "question"
    t.string "question_type"
    t.jsonb "reasoning"
    t.integer "relevant_observation_ids", default: [], array: true
    t.integer "relevant_tracked_object_ids", default: [], array: true
    t.datetime "updated_at", null: false
    t.index ["camera_id"], name: "index_conversation_memories_on_camera_id"
  end

  create_table "observation_tracked_objects", force: :cascade do |t|
    t.float "confidence"
    t.datetime "created_at", null: false
    t.bigint "observation_id", null: false
    t.jsonb "position"
    t.string "state_in_frame"
    t.bigint "tracked_object_id", null: false
    t.datetime "updated_at", null: false
    t.index ["observation_id"], name: "index_observation_tracked_objects_on_observation_id"
    t.index ["tracked_object_id"], name: "index_observation_tracked_objects_on_tracked_object_id"
  end

  create_table "observations", force: :cascade do |t|
    t.jsonb "analysis", default: {}
    t.bigint "camera_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "detected_objects", default: []
    t.string "event_type"
    t.string "image_path"
    t.boolean "is_routine", default: false
    t.text "notification_message"
    t.string "notification_priority", default: "none"
    t.boolean "notification_sent", default: false
    t.datetime "occurred_at", null: false
    t.jsonb "reasoning", default: {}
    t.bigint "routine_id"
    t.bigint "scene_state_id"
    t.float "similarity_score"
    t.string "suppression_reason"
    t.datetime "updated_at", null: false
    t.index ["camera_id", "occurred_at"], name: "index_observations_on_camera_id_and_occurred_at"
    t.index ["camera_id"], name: "index_observations_on_camera_id"
    t.index ["is_routine"], name: "index_observations_on_is_routine"
    t.index ["notification_priority"], name: "index_observations_on_notification_priority"
    t.index ["routine_id"], name: "index_observations_on_routine_id"
    t.index ["scene_state_id"], name: "index_observations_on_scene_state_id"
  end

  create_table "routines", force: :cascade do |t|
    t.boolean "active", default: true
    t.boolean "auto_suppress", default: false
    t.bigint "camera_id", null: false
    t.float "confidence_score", default: 0.0
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "event_signature", default: {}
    t.datetime "first_seen_at"
    t.string "frequency"
    t.datetime "last_seen_at"
    t.string "name", null: false
    t.integer "occurrence_count", default: 0
    t.jsonb "time_pattern", default: {}
    t.datetime "updated_at", null: false
    t.index ["camera_id", "active"], name: "index_routines_on_camera_id_and_active"
    t.index ["camera_id"], name: "index_routines_on_camera_id"
    t.index ["confidence_score"], name: "index_routines_on_confidence_score"
  end

  create_table "scene_states", force: :cascade do |t|
    t.integer "active_object_count", default: 0
    t.bigint "camera_id", null: false
    t.integer "change_magnitude", default: 0
    t.datetime "created_at", null: false
    t.string "lighting"
    t.text "overall_description"
    t.string "snapshot_image_path"
    t.string "temperature_indication"
    t.datetime "timestamp", null: false
    t.datetime "updated_at", null: false
    t.jsonb "weather", default: {}
    t.index ["camera_id", "timestamp"], name: "index_scene_states_on_camera_id_and_timestamp"
    t.index ["camera_id"], name: "index_scene_states_on_camera_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "tracked_objects", force: :cascade do |t|
    t.text "appearance_description"
    t.bigint "camera_id", null: false
    t.float "confidence_score", default: 0.0
    t.datetime "created_at", null: false
    t.datetime "disappeared_at"
    t.integer "duration_minutes", default: 0
    t.datetime "first_detected_at", null: false
    t.string "identifier", null: false
    t.datetime "last_detected_at", null: false
    t.jsonb "metadata", default: {}
    t.string "object_type", null: false
    t.jsonb "position_history", default: []
    t.string "status", default: "present", null: false
    t.datetime "updated_at", null: false
    t.jsonb "visual_fingerprint", default: {}
    t.index ["camera_id", "status", "object_type"], name: "index_tracked_objects_on_camera_id_and_status_and_object_type"
    t.index ["camera_id"], name: "index_tracked_objects_on_camera_id"
    t.index ["identifier"], name: "index_tracked_objects_on_identifier", unique: true
    t.index ["last_detected_at"], name: "index_tracked_objects_on_last_detected_at"
  end

  add_foreign_key "conversation_memories", "cameras"
  add_foreign_key "observation_tracked_objects", "observations"
  add_foreign_key "observation_tracked_objects", "tracked_objects"
  add_foreign_key "observations", "cameras"
  add_foreign_key "observations", "routines"
  add_foreign_key "observations", "scene_states"
  add_foreign_key "routines", "cameras"
  add_foreign_key "scene_states", "cameras"
  add_foreign_key "tracked_objects", "cameras"
end
