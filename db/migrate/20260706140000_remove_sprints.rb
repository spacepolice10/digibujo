# frozen_string_literal: true

class RemoveSprints < ActiveRecord::Migration[8.1]
  def change
    drop_table :sprints do |t|
      t.date :starts_on
      t.date :ends_on
      t.timestamps
    end

    remove_column :user_settings, :sprints_expanded, :boolean
  end
end
