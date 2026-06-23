# frozen_string_literal: true

class CreateArchives < ActiveRecord::Migration[8.1]
  def change
    create_table :archives do |t|
      t.references :archivable, polymorphic: true, null: false
      t.references :user, null: true, foreign_key: true
      t.timestamps
    end

    add_index :archives, %i[archivable_type archivable_id], unique: true,
              name: "index_archives_on_archivable_type_and_archivable_id"
    add_index :archives, :archivable_type
  end
end