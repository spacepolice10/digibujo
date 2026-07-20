# frozen_string_literal: true

class ReplaceMentionsWithProjects < ActiveRecord::Migration[8.1]
  def up
    person_ids = select_values("SELECT id FROM mentions WHERE kind = 'person'")

    if person_ids.any?
      ids = person_ids.join(',')
      execute "DELETE FROM bullet_mentions WHERE mention_id IN (#{ids})"
      execute "DELETE FROM pinned_entities WHERE pinnable_type = 'Mention' AND pinnable_id IN (#{ids})"
      execute "DELETE FROM search_records WHERE searchable_type = 'Mention' AND searchable_id IN (#{ids})"
      execute "DELETE FROM search_selections WHERE searchable_type = 'Mention' AND searchable_id IN (#{ids})"
      execute "DELETE FROM mentions WHERE kind = 'person'"
    end

    rename_table :mentions, :projects
    remove_index :projects, name: 'index_mentions_on_user_id_and_kind_and_name', if_exists: true
    remove_column :projects, :kind, :string
    add_index :projects, %i[user_id name], unique: true, name: 'index_projects_on_user_id_and_name', if_not_exists: true

    rename_table :bullet_mentions, :bullet_projects
    rename_column :bullet_projects, :mention_id, :project_id

    # SQLite may keep/rename the unique index when the column is renamed — avoid duplicate create.
    remove_index :bullet_projects, name: 'index_bullet_mentions_on_bullet_id_and_mention_id', if_exists: true
    remove_index :bullet_projects, name: 'index_bullet_mentions_on_mention_id', if_exists: true
    remove_index :bullet_projects, name: 'index_bullet_projects_on_bullet_id_and_project_id', if_exists: true
    remove_index :bullet_projects, name: 'index_bullet_projects_on_project_id', if_exists: true
    add_index :bullet_projects, %i[bullet_id project_id], unique: true, name: 'index_bullet_projects_on_bullet_id_and_project_id'
    add_index :bullet_projects, :project_id, name: 'index_bullet_projects_on_project_id'

    execute "UPDATE pinned_entities SET pinnable_type = 'Project' WHERE pinnable_type = 'Mention'"
    execute "UPDATE search_records SET searchable_type = 'Project' WHERE searchable_type = 'Mention'"
    execute "UPDATE search_selections SET searchable_type = 'Project' WHERE searchable_type = 'Mention'"

    remove_column :user_settings, :people_expanded, :boolean, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
