class RenameStreamFieldCardableToBulletable < ActiveRecord::Migration[8.1]
  class MigrationStream < ApplicationRecord
    self.table_name = "streams"
  end

  def up
    MigrationStream.find_each do |stream|
      fields = (stream.fields || {}).deep_dup
      next unless fields.key?("cardable_type")

      fields["bulletable_type"] = fields.delete("cardable_type")
      stream.update_columns(fields: fields, updated_at: Time.current)
    end
  end

  def down
    MigrationStream.find_each do |stream|
      fields = (stream.fields || {}).deep_dup
      next unless fields.key?("bulletable_type")

      fields["cardable_type"] = fields.delete("bulletable_type")
      stream.update_columns(fields: fields, updated_at: Time.current)
    end
  end
end
