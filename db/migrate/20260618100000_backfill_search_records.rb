# frozen_string_literal: true

class BackfillSearchRecords < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:search_records)

    SearchReindexJob.perform_now
  end

  def down
    return unless table_exists?(:search_records)

    execute "DELETE FROM search_records_fts" if connection.table_exists?("search_records_fts")
    Search::Record.delete_all
  end
end
