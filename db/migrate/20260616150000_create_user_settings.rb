# frozen_string_literal: true

class CreateUserSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :user_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :logs_open, default: true, null: false
      t.boolean :projects_open, default: true, null: false
      t.boolean :collections_open, default: true, null: false
      t.boolean :spreads_open, default: true, null: false
      t.timestamps
    end

    remove_column :users, :preferences, :json, default: {}, null: false
  end
end
