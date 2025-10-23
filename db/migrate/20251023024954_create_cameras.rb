class CreateCameras < ActiveRecord::Migration[8.1]
  def change
    create_table :cameras do |t|
      t.string :name, null: false
      t.string :rtsp_url, null: false
      t.boolean :active, default: true, null: false
      t.text :description
      t.integer :capture_interval_seconds, default: 5, null: false

      t.timestamps
    end

    add_index :cameras, :active
  end
end
