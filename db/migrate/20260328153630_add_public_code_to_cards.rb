class AddPublicCodeToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :public_code, :string
    add_index :bullets, :public_code, unique: true
  end
end
