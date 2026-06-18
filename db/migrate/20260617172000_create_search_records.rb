# frozen_string_literal: true

class CreateSearchRecords < ActiveRecord::Migration[8.1]
  def up
    create_table :search_records do |t|
      t.references :user, null: false, foreign_key: true
      t.string :searchable_type, null: false
      t.integer :searchable_id, null: false
      t.string :search_name
      t.text :search_body
      t.timestamps

      t.index %i[user_id searchable_type searchable_id],
              unique: true,
              name: "index_search_records_on_user_and_searchable"
    end

    execute <<~SQL.squish
      CREATE VIRTUAL TABLE search_records_fts USING fts5(
        search_name,
        search_body,
        tokenize='unicode61 remove_diacritics 2',
        prefix='2 3 4 5'
      )
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS search_records_fts"
    drop_table :search_records
  end
end
