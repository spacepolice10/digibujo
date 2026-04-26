class AddTriagedAtToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :triaged_at, :datetime
    add_index :cards, %i[user_id triaged_at]
  end
end
