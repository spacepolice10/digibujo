# frozen_string_literal: true

class CreateAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.string :permission, null: false, default: 'read'
      t.string :description

      t.timestamps
    end
    add_index :access_tokens, :token_digest, unique: true
  end
end
