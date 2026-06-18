# frozen_string_literal: true

require "test_helper"

class Search::GlobalRequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "returns empty collections for blank query" do
    @user.projects.create!(name: "alpha")

    results = Search::GlobalRequest.call(user: @user, query: "")

    assert_empty results.projects
    assert_empty results.buckets
    assert_empty results.bullets
    assert_empty results.people
  end

  test "scopes results to the current user" do
    other_user = users(:two)
    @user.projects.create!(name: "mine")
    other_user.projects.create!(name: "mine")

    results = Search::GlobalRequest.call(user: @user, query: "mine")

    assert_equal 1, results.projects.size
    assert_equal @user.id, results.projects.first.user_id
  end

  test "finds people by email in search body" do
    @user.people.create!(name: "alex", email: "alex@example.com")

    results = Search::GlobalRequest.call(user: @user, query: "alex@example.com")

    assert_equal 1, results.people.size
    assert_equal "alex", results.people.first.name
  end

  test "applies fuzzy fallback for near matches" do
    @user.projects.create!(name: "alpha")

    results = Search::GlobalRequest.call(user: @user, query: "alpa")

    assert_equal 1, results.projects.size
    assert_equal "alpha", results.projects.first.name
  end
end
