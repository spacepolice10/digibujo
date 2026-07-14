# frozen_string_literal: true

class UnifyProjectsAndPeopleIntoMentions < ActiveRecord::Migration[8.1]
  class MigrationProject < ApplicationRecord
    self.table_name = "projects"
  end

  class MigrationPerson < ApplicationRecord
    self.table_name = "people"
  end

  class MigrationMention < ApplicationRecord
    self.table_name = "mentions"
  end

  class MigrationBulletProject < ApplicationRecord
    self.table_name = "bullet_projects"
  end

  class MigrationBulletPerson < ApplicationRecord
    self.table_name = "bullet_people"
  end

  class MigrationBulletMention < ApplicationRecord
    self.table_name = "bullet_mentions"
  end

  class MigrationPinnedEntity < ApplicationRecord
    self.table_name = "pinned_entities"
  end

  class MigrationSearchRecord < ApplicationRecord
    self.table_name = "search_records"
  end

  class MigrationSearchSelection < ApplicationRecord
    self.table_name = "search_selections"
  end

  def up
    create_table :mentions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :colour
      t.string :kind, null: false
      t.timestamps
    end
    add_index :mentions, [ :user_id, :kind, :name ], unique: true

    create_table :bullet_mentions do |t|
      t.references :bullet, null: false, foreign_key: true
      t.references :mention, null: false, foreign_key: true
      t.timestamps
    end
    add_index :bullet_mentions, [ :bullet_id, :mention_id ], unique: true

    project_map = migrate_sources!(MigrationProject, kind: "project")
    person_map = migrate_sources!(MigrationPerson, kind: "person")

    migrate_bullet_joins!(MigrationBulletProject, :project_id, project_map)
    migrate_bullet_joins!(MigrationBulletPerson, :person_id, person_map)

    repoint_polymorphic!(MigrationPinnedEntity, "pinnable_type", "pinnable_id", project_map, person_map)
    repoint_polymorphic!(MigrationSearchRecord, "searchable_type", "searchable_id", project_map, person_map)
    repoint_polymorphic!(MigrationSearchSelection, "searchable_type", "searchable_id", project_map, person_map)

    drop_table :bullet_projects
    drop_table :bullet_people
    drop_table :projects
    drop_table :people
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_sources!(source_class, kind:)
    id_map = {}
    kept = {}

    source_class.order(:id).find_each do |row|
      key = [ row.user_id, row.name ]
      if (existing_id = kept[key])
        id_map[row.id] = existing_id
        next
      end

      mention = MigrationMention.create!(
        user_id: row.user_id,
        name: row.name,
        colour: row.colour,
        kind: kind,
        created_at: row.created_at,
        updated_at: row.updated_at
      )
      kept[key] = mention.id
      id_map[row.id] = mention.id
    end

    id_map
  end

  def migrate_bullet_joins!(source_class, foreign_key, id_map)
    now = Time.current
    seen = {}
    rows = []

    source_class.find_each do |join|
      mention_id = id_map[join.public_send(foreign_key)]
      next unless mention_id

      key = [ join.bullet_id, mention_id ]
      next if seen[key]

      seen[key] = true
      rows << {
        bullet_id: join.bullet_id,
        mention_id: mention_id,
        created_at: join.try(:created_at) || now,
        updated_at: join.try(:updated_at) || now
      }
    end

    MigrationBulletMention.insert_all(rows) if rows.any?
  end

  def repoint_polymorphic!(model_class, type_column, id_column, project_map, person_map)
    model_class.where(type_column => "Project").find_each do |row|
      mention_id = project_map[row.public_send(id_column)]
      if mention_id
        row.update_columns(type_column => "Mention", id_column => mention_id)
      else
        row.destroy!
      end
    end

    model_class.where(type_column => "Person").find_each do |row|
      mention_id = person_map[row.public_send(id_column)]
      if mention_id
        row.update_columns(type_column => "Mention", id_column => mention_id)
      else
        row.destroy!
      end
    end
  end
end
