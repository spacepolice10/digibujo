# frozen_string_literal: true

class RenameRecurrenciesToTrackers < ActiveRecord::Migration[8.1]
  def change
    rename_table :recurrencies, :trackers
    rename_table :recurrency_completions, :tracker_completions

    rename_column :tracker_completions, :recurrency_id, :tracker_id

    rename_column :user_settings, :recurrencies_expanded, :trackers_expanded

    add_column :trackers, :stopped_on, :date
  end
end
