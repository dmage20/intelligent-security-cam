class CreateObservationTrackedObjects < ActiveRecord::Migration[8.1]
  def change
    create_table :observation_tracked_objects do |t|
      t.references :observation, null: false, foreign_key: true
      t.references :tracked_object, null: false, foreign_key: true
      t.string :state_in_frame
      t.jsonb :position
      t.float :confidence

      t.timestamps
    end
  end
end
