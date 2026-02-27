class AddPopsOnToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :pops_on, :date
    add_index :cards, [ :user_id, :pops_on ]
  end
end
