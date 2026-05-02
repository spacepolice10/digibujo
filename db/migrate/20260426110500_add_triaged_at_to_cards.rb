class AddTriagedAtToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :triaged_at, :datetime
    add_index :bullets, %i[user_id triaged_at]
  end
end
