# frozen_string_literal: true

class Search::Record::Sqlite::Fts < ApplicationRecord
  self.table_name = "search_records_fts"
  self.primary_key = "rowid"

  attribute :rowid, :integer
  attribute :search_name, :string
  attribute :search_body, :string

  scope :with_rowid, -> { select(:rowid, :search_name, :search_body) }

  class << self
    def upsert(rowid, search_name, search_body)
      connection.exec_query(
        "INSERT OR REPLACE INTO search_records_fts(rowid, search_name, search_body) VALUES (?, ?, ?)",
        "Search::Record::Sqlite::Fts Upsert",
        [ rowid, search_name, search_body ]
      )
    end

    def delete(rowid)
      connection.exec_query(
        "DELETE FROM search_records_fts WHERE rowid = ?",
        "Search::Record::Sqlite::Fts Delete",
        [ rowid ]
      )
    end
  end
end
