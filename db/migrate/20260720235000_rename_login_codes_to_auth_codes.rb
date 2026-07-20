# frozen_string_literal: true

class RenameLoginCodesToAuthCodes < ActiveRecord::Migration[8.1]
  def change
    rename_table :login_codes, :auth_codes
  end
end
