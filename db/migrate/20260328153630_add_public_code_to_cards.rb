class AddPublicCodeToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :public_code, :string
    add_index :cards, :public_code, unique: true
  end
end
