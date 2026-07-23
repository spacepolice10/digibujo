# frozen_string_literal: true

class AddArchivedExpandedToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :archived_expanded, :boolean, default: true, null: false
  end
end
