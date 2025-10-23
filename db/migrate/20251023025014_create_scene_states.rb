class CreateSceneStates < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_states do |t|
      t.references :camera, null: false, foreign_key: true
      t.datetime :timestamp, null: false
      t.jsonb :weather, default: {}
      t.string :lighting
      t.string :temperature_indication
      t.text :overall_description
      t.integer :active_object_count, default: 0
      t.integer :change_magnitude, default: 0
      t.string :snapshot_image_path

      t.timestamps
    end

    add_index :scene_states, [:camera_id, :timestamp]
  end
end
