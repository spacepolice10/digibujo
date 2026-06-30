# frozen_string_literal: true

class CreateVoices < ActiveRecord::Migration[8.1]
  def change
    create_table :voices do |t|
      t.integer :duration_seconds

      t.timestamps
    end
  end
end
