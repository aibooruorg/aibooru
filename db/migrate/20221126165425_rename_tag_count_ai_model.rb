class RenameTagCountAIModel < ActiveRecord::Migration[7.0]
  def change
    rename_column :posts, :tag_count_ai_model, :tag_count_model
  end
end
