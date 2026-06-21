# frozen_string_literal: true

class AddColourAndIconToRecurrencies < ActiveRecord::Migration[8.1]
  def change
    change_table :recurrencies, bulk: true do |t|
      t.string :colour
      t.string :icon
    end
  end
end
