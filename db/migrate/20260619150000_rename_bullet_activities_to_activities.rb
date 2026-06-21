# frozen_string_literal: true

class RenameBulletActivitiesToActivities < ActiveRecord::Migration[8.1]
  def up
    rename_table :bullet_activities, :activities
    rename_column :activities, :bullet_id, :subject_id

    add_column :activities, :subject_type, :string
    execute "UPDATE activities SET subject_type = 'Bullet'"
    change_column_null :activities, :subject_type, false

    remove_index :activities, column: %i[subject_id created_at], if_exists: true
    add_index :activities, %i[subject_type subject_id created_at]
  end

  def down
    remove_index :activities, column: %i[subject_type subject_id created_at]

    remove_column :activities, :subject_type
    rename_column :activities, :subject_id, :bullet_id
    rename_table :activities, :bullet_activities

    add_index :bullet_activities, %i[bullet_id created_at], name: "index_bullet_activities_on_bullet_id_and_created_at"
  end
end
