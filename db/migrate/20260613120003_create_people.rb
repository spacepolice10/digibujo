# frozen_string_literal: true

class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :number
      t.string :colour
      t.string :icon
      t.timestamps
    end

    add_index :people, %i[user_id name], unique: true

    create_table :bullet_people do |t|
      t.references :bullet, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.timestamp :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :bullet_people, %i[bullet_id person_id], unique: true
  end
end
