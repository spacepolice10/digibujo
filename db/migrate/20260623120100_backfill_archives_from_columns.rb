# frozen_string_literal: true

class BackfillArchivesFromColumns < ActiveRecord::Migration[8.1]
  def up
    backfill_subject("Bullet", "bullets")
    backfill_subject("Bucket", "buckets")
  end

  def down
    execute "DELETE FROM archives WHERE archivable_type IN ('Bullet', 'Bucket')"
  end

  private

  def backfill_subject(archivable_type, table)
    rows = select_all(<<~SQL.squish)
      SELECT id, user_id, archives_on, updated_at, created_at
      FROM #{table}
      WHERE archived = 1
    SQL

    rows.each do |row|
      archived_at = row["archives_on"] || row["updated_at"] || row["created_at"]
      execute <<~SQL.squish
        INSERT INTO archives (archivable_type, archivable_id, user_id, created_at, updated_at)
        VALUES ('#{archivable_type}', #{row["id"]}, #{row["user_id"] || "NULL"}, '#{archived_at}', '#{archived_at}')
      SQL
    end
  end
end