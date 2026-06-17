class AddIndentedToBulletsAndCreateTitles < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :indented, :boolean, default: false, null: false

    create_table :titles do |t|
      t.string :text, null: false
      t.timestamps
    end
  end
end
