# frozen_string_literal: true

class RemoveIndentedFromBullets < ActiveRecord::Migration[8.1]
  def change
    remove_column :bullets, :indented, :boolean, default: false, null: false
  end
end
