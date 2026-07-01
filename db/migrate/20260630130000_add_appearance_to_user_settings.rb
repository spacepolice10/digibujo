# frozen_string_literal: true

class AddAppearanceToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :appearance, :string, default: "default", null: false
  end
end
