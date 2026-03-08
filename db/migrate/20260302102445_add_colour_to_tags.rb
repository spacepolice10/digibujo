class AddColourToTags < ActiveRecord::Migration[8.1]
  def change
    add_column :tags, :colour, :string
  end
end
