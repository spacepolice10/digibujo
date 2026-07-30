# frozen_string_literal: true

class RenameTrackerCompletionsToStatuses < ActiveRecord::Migration[8.1]
  def change
    rename_table :tracker_completions, :tracker_statuses
  end
end
