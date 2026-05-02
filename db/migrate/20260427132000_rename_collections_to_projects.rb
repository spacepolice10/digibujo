class RenameCollectionsToProjects < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :bullets, :collections if foreign_key_exists?(:bullets, :collections)

    if index_exists?(:bullets, :collection_id)
      rename_index :bullets, "index_cards_on_collection_id", "index_cards_on_project_id"
    end
    rename_column :bullets, :collection_id, :project_id

    rename_table :collections, :projects
    rename_index :projects, "index_collections_on_user_id", "index_projects_on_user_id"
    rename_index :projects, "index_collections_on_user_id_and_name", "index_projects_on_user_id_and_name"

    add_foreign_key :bullets, :projects

    execute <<~SQL
      UPDATE streams
      SET fields = json_patch(
        json_remove(fields, '$.collections'),
        json_object('projects', json_extract(fields, '$.collections'))
      )
      WHERE json_extract(fields, '$.collections') IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      UPDATE streams
      SET fields = json_patch(
        json_remove(fields, '$.projects'),
        json_object('collections', json_extract(fields, '$.projects'))
      )
      WHERE json_extract(fields, '$.projects') IS NOT NULL
    SQL

    remove_foreign_key :bullets, :projects if foreign_key_exists?(:bullets, :projects)

    if index_exists?(:bullets, :project_id)
      rename_index :bullets, "index_cards_on_project_id", "index_cards_on_collection_id"
    end
    rename_column :bullets, :project_id, :collection_id

    rename_table :projects, :collections
    rename_index :collections, "index_projects_on_user_id", "index_collections_on_user_id"
    rename_index :collections, "index_projects_on_user_id_and_name", "index_collections_on_user_id_and_name"

    add_foreign_key :bullets, :collections
  end
end
