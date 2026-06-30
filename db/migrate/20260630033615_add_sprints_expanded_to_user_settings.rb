# frozen_string_literal: true

class AddSprintsExpandedToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :sprints_expanded, :boolean, default: true, null: false
  end
end
