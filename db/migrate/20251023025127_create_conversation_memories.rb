class CreateConversationMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_memories do |t|
      t.references :camera, null: false, foreign_key: true
      t.text :question
      t.string :question_type
      t.text :answer
      t.jsonb :reasoning
      t.jsonb :context_used
      t.datetime :asked_at
      t.integer :confidence_in_answer
      t.integer :relevant_observation_ids, array: true, default: []
      t.integer :relevant_tracked_object_ids, array: true, default: []
      t.text :images_analyzed, array: true, default: []

      t.timestamps
    end
  end
end
