# frozen_string_literal: true

class CreateRecurrencies < ActiveRecord::Migration[8.1]
  def change
    create_table :recurrencies do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.json :schedule, null: false, default: { "kind" => "daily" }
      t.date :active_from
      t.date :active_to

      t.timestamps
    end

    add_index :recurrencies, %i[user_id created_at]
  end
end
