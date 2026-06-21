# frozen_string_literal: true

class CreateRecurrencyCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :recurrency_completions do |t|
      t.references :recurrency, null: false, foreign_key: true
      t.date :date, null: false
      t.datetime :completed_at, null: false

      t.timestamps
    end

    add_index :recurrency_completions, %i[recurrency_id date], unique: true
  end
end
