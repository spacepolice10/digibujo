# frozen_string_literal: true

require "test_helper"

class Search::GlobalRequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "returns empty entries for blank query" do
    @user.projects.create!(name: "alpha")

    entries = Search::GlobalRequest.call(user: @user, query: "")

    assert_empty entries
  end

  test "scopes results to the current user" do
    other_user = users(:two)
    @user.projects.create!(name: "mine")
    other_user.projects.create!(name: "mine")

    entries = Search::GlobalRequest.call(user: @user, query: "mine")

    assert_equal 1, entries.size
    assert_equal "Project", entries.first.class.name
    assert_equal @user.id, entries.first.user_id
  end

  test "finds people by email in search body" do
    alex = @user.people.create!(name: "alex")
    alex.handles.create!(kind: :email, data: "alex@example.com")

    entries = Search::GlobalRequest.call(user: @user, query: "alex@example.com")

    assert_equal 1, entries.size
    assert_equal "Person", entries.first.class.name
    assert_equal "alex", entries.first.name
  end

  test "applies fuzzy fallback for near matches" do
    @user.projects.create!(name: "alpha")

    entries = Search::GlobalRequest.call(user: @user, query: "alpa")

    assert_equal 1, entries.size
    assert_equal "alpha", entries.first.name
  end

  test "returns a flat ranked list across entity types" do
    @user.projects.create!(name: "alpha project")
    @user.bullets.create!(bulletable: Task.create!, body: "alpha task")

    entries = Search::GlobalRequest.call(user: @user, query: "alpha")

    assert_equal 2, entries.size
    assert_includes entries.map { |entry| entry.class.name }, "Project"
    assert_includes entries.map { |entry| entry.class.name }, "Bullet"
  end
end
