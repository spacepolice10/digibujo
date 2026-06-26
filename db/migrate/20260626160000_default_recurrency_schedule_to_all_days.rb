# frozen_string_literal: true

class DefaultRecurrencyScheduleToAllDays < ActiveRecord::Migration[8.1]
  def change
    change_column_default :recurrencies, :schedule, from: { "days" => [1, 2, 3, 4, 5] }, to: { "days" => (0..6).to_a }
  end
end
