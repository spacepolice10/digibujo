# frozen_string_literal: true

module Search::Record::Sqlite
  extend ActiveSupport::Concern

  included do
    after_save :upsert_to_fts5_table
    after_destroy :remove_from_fts5_table

    scope :matching, ->(query) {
      joins("INNER JOIN search_records_fts ON search_records_fts.rowid = #{table_name}.id")
        .where("search_records_fts MATCH ?", query)
    }
  end

  class_methods do
    def search(user:, query:, limit: 50)
      fts_query = Search::TermBuilder.build(query)
      return none if fts_query.blank?

      matching(fts_query)
        .where(user_id: user.id)
        .select(
          "#{table_name}.*",
          "bm25(search_records_fts, 10.0, 1.0) AS fts_rank"
        )
        .order(Arel.sql("fts_rank"))
        .limit(limit)
    end
  end

  private

  def upsert_to_fts5_table
    Search::Record::Sqlite::Fts.upsert(id, search_name, search_body)
  end

  def remove_from_fts5_table
    Search::Record::Sqlite::Fts.delete(id)
  end
end
