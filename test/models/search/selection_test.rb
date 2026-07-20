# frozen_string_literal: true

require 'test_helper'

class Search::SelectionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = create_project!(@user, name: 'alpha')
  end

  test 'record! upserts the same target' do
    Search::Selection.record!(
      user: @user,
      searchable_type: 'Project',
      searchable_id: @project.id,
      query: 'alp'
    )

    travel 1.hour do
      Search::Selection.record!(
        user: @user,
        searchable_type: 'Project',
        searchable_id: @project.id,
        query: 'alpha'
      )

      selection = @user.search_selections.sole
      assert_equal 'alpha', selection.query
      assert_in_delta Time.current, selection.selected_at, 1.second
    end

    assert_equal 1, @user.search_selections.count
  end

  test 'record! keeps at most LIMIT selections per user' do
    projects = (Search::Selection::LIMIT + 1).times.map { |i| create_project!(@user, name: "project #{i}") }

    projects.each do |project|
      Search::Selection.record!(
        user: @user,
        searchable_type: 'Project',
        searchable_id: project.id
      )
    end

    assert_equal Search::Selection::LIMIT, @user.search_selections.count
    assert_not_includes @user.search_selections.pluck(:searchable_id), projects.first.id
  end

  test 'in_menu returns recent selections up to LIMIT' do
    projects = (Search::Selection::LIMIT + 1).times.map { |i| create_project!(@user, name: "menu project #{i}") }

    projects.each do |project|
      Search::Selection.record!(
        user: @user,
        searchable_type: 'Project',
        searchable_id: project.id
      )
    end

    selections = Search::Selection.in_menu(@user)

    assert_equal Search::Selection::LIMIT, selections.size
    assert_equal projects.last.id, selections.first.searchable_id
  end

  test 'in_menu skips selections whose searchable was deleted' do
    deleted = create_project!(@user, name: 'gone')
    kept = create_project!(@user, name: 'kept')

    Search::Selection.record!(user: @user, searchable_type: 'Project', searchable_id: deleted.id)
    Search::Selection.record!(user: @user, searchable_type: 'Project', searchable_id: kept.id)

    deleted.destroy!

    selections = Search::Selection.in_menu(@user)

    assert_equal 1, selections.size
    assert_equal kept, selections.first.searchable
  end

  test 'complete! removes bullet from recent selections' do
    bullet = create_bullet!(@user, bulletable: Task.new(body: 'Finish me'))

    Search::Selection.record!(
      user: @user,
      searchable_type: 'Bullet',
      searchable_id: bullet.id
    )

    bullet.bulletable.complete!

    assert_empty Search::Selection.in_menu(@user)
  end

  test 'in_menu returns selections with searchable loaded' do
    Search::Selection.record!(
      user: @user,
      searchable_type: 'Project',
      searchable_id: @project.id
    )

    selection = Search::Selection.in_menu(@user).sole

    assert_equal @project, selection.searchable
  end
end
