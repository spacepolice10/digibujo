# frozen_string_literal: true

class RenameHookCodesToHooks < ActiveRecord::Migration[8.1]
  def change
    rename_table :hook_codes, :hooks
  end
end
