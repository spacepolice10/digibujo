# frozen_string_literal: true

class RemoveActiveFromFromRecurrencies < ActiveRecord::Migration[8.1]
  def change
    remove_column :recurrencies, :active_from, :date
  end
end
