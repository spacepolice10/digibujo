# frozen_string_literal: true

class NormalizePostponedActivitiesToPopped < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE bullet_activities SET action = 'popped' WHERE action = 'postponed'
    SQL
  end
end
