# frozen_string_literal: true

class UnlinkTrackerFromMonthlylog < ActiveRecord::Migration[7.1]
  def change
    add_reference :trackers, :user, foreign_key: true
    add_column :trackers, :start_date, :date

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE trackers
          SET user_id = (SELECT monthlylogs.user_id FROM monthlylogs WHERE monthlylogs.id = trackers.monthlylog_id),
              start_date = (SELECT monthlylogs.period_from FROM monthlylogs WHERE monthlylogs.id = trackers.monthlylog_id)
        SQL
      end
    end

    change_column_null :trackers, :user_id, false
    change_column_null :trackers, :start_date, false

    remove_foreign_key :trackers, :monthlylogs
    remove_column :trackers, :monthlylog_id

    remove_index :trackers, name: "index_trackers_on_user_id_and_created_at"
    add_index :trackers, [:user_id, :created_at]
  end
end
