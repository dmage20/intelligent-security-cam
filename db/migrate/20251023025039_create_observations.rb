class CreateObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :observations do |t|
      t.references :camera, null: false, foreign_key: true
      t.references :scene_state, foreign_key: true
      t.string :event_type
      t.text :description
      t.string :image_path
      t.jsonb :detected_objects, default: []
      t.jsonb :analysis, default: {}
      t.jsonb :reasoning, default: {}
      t.datetime :occurred_at, null: false
      t.boolean :is_routine, default: false
      t.references :routine, foreign_key: true
      t.boolean :notification_sent, default: false
      t.string :suppression_reason
      t.string :notification_priority, default: 'none'
      t.text :notification_message
      t.float :similarity_score

      t.timestamps
    end

    add_index :observations, [:camera_id, :occurred_at]
    add_index :observations, :is_routine
    add_index :observations, :notification_priority
  end
end
