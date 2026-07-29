# frozen_string_literal: true

class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :webhooks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :payload_url, null: false
      t.string :signing_secret, null: false
      t.json :subscribed_actions, null: false, default: []
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
