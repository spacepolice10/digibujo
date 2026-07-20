# frozen_string_literal: true

class CreateDaylogPictures < ActiveRecord::Migration[8.1]
  def change
    create_table :daylog_pictures do |t|
      t.references :daylog, null: false, foreign_key: true
      t.date :date, null: false
      t.timestamps
    end
    add_index :daylog_pictures, %i[daylog_id date], unique: true
  end
end
