# frozen_string_literal: true

class RemoveActiveToFromRecurrencies < ActiveRecord::Migration[8.1]
  def change
    remove_column :recurrencies, :active_to, :date
  end
end
