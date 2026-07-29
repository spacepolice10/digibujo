# frozen_string_literal: true

class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
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
