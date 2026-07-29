# frozen_string_literal: true

class RenameAccessTokensToAccessCodes < ActiveRecord::Migration[8.1]
  def change
    rename_table :access_tokens, :access_codes
    rename_column :access_codes, :token_digest, :code_digest
    rename_column :access_codes, :token_prefix, :code_prefix
  end
end
