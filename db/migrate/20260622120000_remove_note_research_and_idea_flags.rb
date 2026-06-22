# frozen_string_literal: true

class RemoveNoteResearchAndIdeaFlags < ActiveRecord::Migration[8.1]
  def change
    change_table :notes, bulk: true do |t|
      t.remove :awaits_research, type: :boolean, default: false, null: false
      t.remove :idea, type: :boolean, default: false, null: false
    end
  end
end
