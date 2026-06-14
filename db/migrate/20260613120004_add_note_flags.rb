# frozen_string_literal: true

class AddNoteFlags < ActiveRecord::Migration[8.1]
  def change
    change_table :notes, bulk: true do |t|
      t.boolean :awaits_research, default: false, null: false
      t.boolean :idea, default: false, null: false
    end
  end
end
