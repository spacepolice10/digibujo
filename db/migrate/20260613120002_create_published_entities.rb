# frozen_string_literal: true

class CreatePublishedEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :published_entities do |t|
      t.references :user, null: false, foreign_key: true
      t.references :publishable, polymorphic: true, null: false
      t.string :code, null: false
      t.datetime :published_at, null: false
      t.timestamps
    end

    add_index :published_entities, :code, unique: true
    add_index :published_entities, %i[user_id publishable_type publishable_id],
              unique: true,
              name: 'idx_published_on_user_and_publishable'
  end
end
