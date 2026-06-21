# frozen_string_literal: true

require "test_helper"

class Search::SelectionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = create_project!(@user, name: "alpha")
  end

  test "record! upserts the same target" do
    Search::Selection.record!(
      user: @user,
      searchable_type: "Project",
      searchable_id: @project.id,
      query: "alp"
    )

    travel 1.hour do
      Search::Selection.record!(
        user: @user,
        searchable_type: "Project",
        searchable_id: @project.id,
        query: "alpha"
      )

      selection = @user.search_selections.sole
      assert_equal "alpha", selection.query
      assert_in_delta Time.current, selection.selected_at, 1.second
    end

    assert_equal 1, @user.search_selections.count
  end

  test "record! keeps at most STORE_LIMIT selections per user" do
    projects = 11.times.map { |i| create_project!(@user, name: "project #{i}") }

    projects.each do |project|
      Search::Selection.record!(
        user: @user,
        searchable_type: "Project",
        searchable_id: project.id
      )
    end

    assert_equal Search::Selection::STORE_LIMIT, @user.search_selections.count
    assert_not_includes @user.search_selections.pluck(:searchable_id), projects.first.id
  end

  test "for_menu returns recent selections up to MENU_LIMIT" do
    projects = 8.times.map { |i| create_project!(@user, name: "menu project #{i}") }

    projects.each do |project|
      Search::Selection.record!(
        user: @user,
        searchable_type: "Project",
        searchable_id: project.id
      )
    end

    selections = Search::Selection.for_menu(@user)

    assert_equal Search::Selection::MENU_LIMIT, selections.size
    assert_equal projects.last.id, selections.first.searchable_id
  end

  test "for_menu skips selections whose searchable was deleted" do
    deleted = create_project!(@user, name: "gone")
    kept = create_project!(@user, name: "kept")

    Search::Selection.record!(user: @user, searchable_type: "Project", searchable_id: deleted.id)
    Search::Selection.record!(user: @user, searchable_type: "Project", searchable_id: kept.id)

    deleted.destroy!

    selections = Search::Selection.for_menu(@user)

    assert_equal 1, selections.size
    assert_equal kept, selections.first.searchable
  end

  test "to_entry wraps searchable for palette rendering" do
    Search::Selection.record!(
      user: @user,
      searchable_type: "Project",
      searchable_id: @project.id
    )

    entry = @user.search_selections.sole.to_entry

    assert_equal @project, entry.entity
    assert_equal "Project", entry.searchable_type
  end
end
