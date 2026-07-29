# frozen_string_literal: true

class ReplaceOutboundWebhooksWithInbound < ActiveRecord::Migration[8.1]
  def up
    drop_table :webhook_deliveries, if_exists: true
    drop_table :webhooks, if_exists: true

    create_table :webhooks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :webhooks, :token_digest, unique: true

    add_column :bullets, :author_name, :string
  end

  def down
    remove_column :bullets, :author_name

    drop_table :webhooks, if_exists: true

    create_table :webhooks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :payload_url, null: false
      t.string :signing_secret, null: false
      t.json :subscribed_actions, null: false, default: []
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    create_table :webhook_deliveries do |t|
      t.references :webhook, null: false, foreign_key: true
      t.string :event_action, null: false
      t.string :state, null: false, default: 'pending'
      t.text :payload
      t.json :request_headers
      t.integer :response_code
      t.text :response_error

      t.timestamps
    end
  end
end
