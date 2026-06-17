class RemoveTextFromTitles < ActiveRecord::Migration[8.1]
  def change
    remove_column :titles, :text, :string
  end
end
