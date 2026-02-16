class CreateFilters < ActiveRecord::Migration[8.1]
  def change
    create_table :filters do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :name
      t.json :fields, null: false, default: {}
      t.timestamps
    end
  end
end
