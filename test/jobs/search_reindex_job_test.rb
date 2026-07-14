# frozen_string_literal: true

require "test_helper"

class SearchReindexJobTest < ActiveSupport::TestCase
  test "rebuilds search records for searchable models" do
    user = users(:one)
    project = create_project!(user, name: "reindex me")
    Search::Record.delete_all

    SearchReindexJob.perform_now

    record = Search::Record.find_by(searchable: project)

    assert record
    assert_equal "reindex me", record.search_name
  end
end
