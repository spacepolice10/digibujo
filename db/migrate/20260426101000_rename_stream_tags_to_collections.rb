class RenameStreamTagsToCollections < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE streams
      SET fields = json_patch(
        json_remove(fields, '$.tags'),
        json_object('collections', json_extract(fields, '$.tags'))
      )
      WHERE json_extract(fields, '$.tags') IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      UPDATE streams
      SET fields = json_patch(
        json_remove(fields, '$.collections'),
        json_object('tags', json_extract(fields, '$.collections'))
      )
      WHERE json_extract(fields, '$.collections') IS NOT NULL
    SQL
  end
end
