# frozen_string_literal: true

class DropLegacyColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :bullets, :pinned, :boolean if column_exists?(:bullets, :pinned)
    remove_column :bullets, :public_code, :string if column_exists?(:bullets, :public_code)
    remove_column :projects, :pinned, :boolean if column_exists?(:projects, :pinned)
  end
end
