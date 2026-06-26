# frozen_string_literal: true

class RenameTaskDoneToCompleted < ActiveRecord::Migration[8.1]
  def change
    rename_column :tasks, :done, :completed
    rename_column :tasks, :done_at, :completed_at
  end
end
