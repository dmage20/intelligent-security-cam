class AddAgentDvrOidToCameras < ActiveRecord::Migration[8.1]
  def change
    add_column :cameras, :agent_dvr_oid, :integer
  end
end
