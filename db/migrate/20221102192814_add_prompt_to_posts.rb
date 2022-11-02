class AddPromptToPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :prompt, :text, null: true
  end
end
