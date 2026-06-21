class CreateSearchSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :search_selections do |t|
      t.references :user, null: false, foreign_key: true
      t.references :searchable, polymorphic: true, null: false
      t.datetime :selected_at, null: false
      t.string :query

      t.timestamps
    end

    add_index :search_selections, %i[user_id searchable_type searchable_id],
              unique: true, name: "index_search_selections_on_user_and_searchable"
    add_index :search_selections, %i[user_id selected_at]
  end
end
