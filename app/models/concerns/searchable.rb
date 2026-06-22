# frozen_string_literal: true

module Searchable
  extend ActiveSupport::Concern

  included do
    after_create_commit :create_in_search_index
    after_update_commit :update_in_search_index
    after_destroy_commit :remove_from_search_index
    before_destroy :remove_search_selections
  end

  def reindex
    update_in_search_index
  end

  private

  def create_in_search_index
    Search::Record.upsert!(search_record_attributes) if searchable?
  end

  def update_in_search_index
    if searchable?
      Search::Record.upsert!(search_record_attributes)
    else
      remove_from_search_index
    end
  end

  def remove_from_search_index
    Search::Record.find_by(
      searchable_type: self.class.name,
      searchable_id: id
    )&.destroy
  end

  def remove_search_selections
    Search::Selection.where(searchable_type: self.class.name, searchable_id: id).delete_all
  end

  def search_record_attributes
    {
      user_id: search_user_id,
      searchable_type: self.class.name,
      searchable_id: id,
      search_name: search_name,
      search_body: search_record_body
    }
  end

  def search_record_body
    search_body&.truncate_bytes(Search::Record::SEARCH_CONTENT_LIMIT, omission: "")
  end

  def searchable?
    true
  end

  def search_user_id
    user_id
  end
end
