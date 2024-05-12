class CreateAIModels < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_models do |t|
      t.string :name, null: false
      t.text :description
      t.string :model_hash, null: false, index: true
      t.string :sha_hash, null: false, index: true
      t.string :magnet

      t.references :creator, index: true, foreign_key: {to_table: :users}
      t.references :updater, index: true, foreign_key: {to_table: :users}

      t.timestamps
    end

    add_index :ai_models, :name, using: :gin, opclass: :gin_trgm_ops
  end
end
