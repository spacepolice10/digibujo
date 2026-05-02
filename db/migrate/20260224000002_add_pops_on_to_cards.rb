class AddPopsOnToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :pops_on, :date
    add_index :bullets, [ :user_id, :pops_on ]
  end
end
