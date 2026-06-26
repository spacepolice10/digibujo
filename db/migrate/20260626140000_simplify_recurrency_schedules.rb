# frozen_string_literal: true

class SimplifyRecurrencySchedules < ActiveRecord::Migration[8.1]
  def up
    Recurrency.reset_column_information
    Recurrency.find_each do |recurrency|
      recurrency.update_column(:schedule, schedule_from_legacy(recurrency.schedule))
    end

    change_column_default :recurrencies, :schedule, from: { "kind" => "daily" }, to: { "days" => [1, 2, 3, 4, 5] }
    add_column :user_settings, :recurrencies_expanded, :boolean, default: true, null: false
  end

  def down
    remove_column :user_settings, :recurrencies_expanded
    change_column_default :recurrencies, :schedule, from: { "days" => [1, 2, 3, 4, 5] }, to: { "kind" => "daily" }
  end

  private

  def schedule_from_legacy(schedule)
    case schedule["kind"]
    when "weekdays"
      { "days" => [1, 2, 3, 4, 5] }
    when "custom"
      { "days" => Array(schedule["days"]).map(&:to_i).uniq.sort }
    else
      { "days" => [0, 1, 2, 3, 4, 5, 6] }
    end
  end
end
