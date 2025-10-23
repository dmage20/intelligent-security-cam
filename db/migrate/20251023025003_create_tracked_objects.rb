class CreateTrackedObjects < ActiveRecord::Migration[8.1]
  def change
    create_table :tracked_objects do |t|
      t.references :camera, null: false, foreign_key: true
      t.string :object_type, null: false
      t.string :identifier, null: false
      t.datetime :first_detected_at, null: false
      t.datetime :last_detected_at, null: false
      t.datetime :disappeared_at
      t.string :status, default: 'present', null: false
      t.integer :duration_minutes, default: 0
      t.jsonb :position_history, default: []
      t.text :appearance_description
      t.jsonb :visual_fingerprint, default: {}
      t.float :confidence_score, default: 0.0
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :tracked_objects, [:camera_id, :status, :object_type]
    add_index :tracked_objects, :identifier, unique: true
    add_index :tracked_objects, :last_detected_at
  end
end
