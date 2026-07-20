# frozen_string_literal: true

class CreateFutureMonthlylogs < ActiveRecord::Migration[8.1]
  def change
    create_table :future_monthlylogs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :future, null: false, foreign_key: true
      t.timestamps
    end
  end
end
