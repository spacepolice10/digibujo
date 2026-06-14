# frozen_string_literal: true

class CreatePinnedEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :pinned_entities do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pinnable, polymorphic: true, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :pinned_entities, %i[user_id pinnable_type pinnable_id],
              unique: true,
              name: "idx_pinned_entities_on_user_and_pinnable"
    add_index :pinned_entities, %i[user_id position]
  end
end
