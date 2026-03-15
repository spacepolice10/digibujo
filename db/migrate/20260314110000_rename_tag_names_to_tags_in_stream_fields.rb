class RenameTagNamesToTagsInStreamFields < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE streams
      SET fields = json_patch(json_remove(fields, '$.tag_names'), json_object('tags', json_extract(fields, '$.tag_names')))
      WHERE json_extract(fields, '$.tag_names') IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      UPDATE streams
      SET fields = json_patch(json_remove(fields, '$.tags'), json_object('tag_names', json_extract(fields, '$.tags')))
      WHERE json_extract(fields, '$.tags') IS NOT NULL
    SQL
  end
end
