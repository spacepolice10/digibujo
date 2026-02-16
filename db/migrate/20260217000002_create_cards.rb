class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.belongs_to :cardable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
