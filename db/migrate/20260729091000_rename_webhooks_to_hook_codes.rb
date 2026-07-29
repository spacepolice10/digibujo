# frozen_string_literal: true

class RenameWebhooksToHookCodes < ActiveRecord::Migration[8.1]
  def change
    rename_table :webhooks, :hook_codes
    rename_column :hook_codes, :token_digest, :code_digest
    rename_column :hook_codes, :token_prefix, :code_prefix
  end
end
