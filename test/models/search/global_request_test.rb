# frozen_string_literal: true

require "test_helper"

class Search::GlobalRequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "returns empty entries for blank query" do
    @user.projects.create!(name: "alpha")

    results = Search::GlobalRequest.call(user: @user, query: "")

    assert_empty results.entries
  end

  test "scopes results to the current user" do
    other_user = users(:two)
    @user.projects.create!(name: "mine")
    other_user.projects.create!(name: "mine")

    results = Search::GlobalRequest.call(user: @user, query: "mine")

    assert_equal 1, results.entries.size
    assert_equal "Project", results.entries.first.searchable_type
    assert_equal @user.id, results.entries.first.entity.user_id
  end

  test "finds people by email in search body" do
    alex = @user.people.create!(name: "alex")
    alex.handles.create!(kind: :email, data: "alex@example.com")

    results = Search::GlobalRequest.call(user: @user, query: "alex@example.com")

    assert_equal 1, results.entries.size
    assert_equal "Person", results.entries.first.searchable_type
    assert_equal "alex", results.entries.first.entity.name
  end

  test "applies fuzzy fallback for near matches" do
    @user.projects.create!(name: "alpha")

    results = Search::GlobalRequest.call(user: @user, query: "alpa")

    assert_equal 1, results.entries.size
    assert_equal "alpha", results.entries.first.entity.name
  end

  test "returns a flat ranked list across entity types" do
    @user.projects.create!(name: "alpha project")
    @user.bullets.create!(bulletable: Task.create!, body: "alpha task")

    results = Search::GlobalRequest.call(user: @user, query: "alpha")

    assert_equal 2, results.entries.size
    assert_includes results.entries.map(&:searchable_type), "Project"
    assert_includes results.entries.map(&:searchable_type), "Bullet"
  end
end
