# frozen_string_literal: true

class RenameUserSettingsColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :user_settings, :logs_open,        :logs_expanded
    rename_column :user_settings, :projects_open,    :projects_expanded
    rename_column :user_settings, :collections_open, :collections_expanded
    rename_column :user_settings, :spreads_open,     :spreads_expanded
  end
end
