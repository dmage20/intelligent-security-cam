class CreateRoutines < ActiveRecord::Migration[8.1]
  def change
    create_table :routines do |t|
      t.references :camera, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.jsonb :event_signature, default: {}
      t.jsonb :time_pattern, default: {}
      t.string :frequency
      t.float :confidence_score, default: 0.0
      t.integer :occurrence_count, default: 0
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.boolean :active, default: true
      t.boolean :auto_suppress, default: false

      t.timestamps
    end

    add_index :routines, [:camera_id, :active]
    add_index :routines, :confidence_score
  end
end
