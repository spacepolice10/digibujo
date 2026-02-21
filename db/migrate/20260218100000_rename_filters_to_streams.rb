class RenameFiltersToStreams < ActiveRecord::Migration[8.1]
  def change
    rename_table :filters, :streams
  end
end
