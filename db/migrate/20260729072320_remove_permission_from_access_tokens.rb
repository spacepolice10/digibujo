# frozen_string_literal: true

class RemovePermissionFromAccessTokens < ActiveRecord::Migration[8.1]
  def change
    remove_column :access_tokens, :permission, :string, default: 'read', null: false
  end
end
