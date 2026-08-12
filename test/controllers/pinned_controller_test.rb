# frozen_string_literal: true

require 'test_helper'

class PinnedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index renders flat list on mobile (direct visit)' do
    get pinned_index_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select '.layout--container-header h1', text: 'Pins'
    assert_select 'a.button[data-content="text"][aria-label="Back to Home"]', text: /Home/
    assert_select '.layout--surface[data-elevation="1"][data-padding="true"]'
    assert_select 'footer.footer', count: 1
    assert_select 'nav.tabbar--navigation a[href=?]', activities_path
    assert_select 'nav.tabbar--navigation a.tabbar--item-active[href=?]', pinned_index_path, count: 0
  end

  test 'index renders flat list on desktop (direct visit)' do
    get pinned_index_path

    assert_response :success
    assert_select '.layout--container-header h1', text: 'Pins'
    assert_select 'a.button[data-content="text"][aria-label="Back to Home"]', text: /Home/
    assert_select '.layout--surface[data-elevation="1"][data-padding="true"]'
    assert_select 'footer.footer', count: 1
  end

  test 'mobile flat list includes pinned bullet' do
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Pinned bullet')
    PinnedEntity.create!(user: @user, pinnable: bullet)

    get pinned_index_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select '.layout--list-item', text: /Pinned bullet/, count: 1
  end

  test 'mobile flat list includes pinned project' do
    project = create_project!(@user, name: 'Pinned project')
    project.pin!

    get pinned_index_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select '.layout--list-item a[href=?]', project_path(project)
  end

  test 'mobile flat list includes pinned bucket' do
    collection = create_collection!(@user, name: 'Pinned collection')
    collection.bucket.pin!

    get pinned_index_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select '.layout--list-item a[href=?]', bucket_path(collection.bucket)
  end

  test 'pinned list popover loads all entity types' do
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Pinned bullet')
    PinnedEntity.create!(user: @user, pinnable: bullet)
    project = create_project!(@user, name: 'Popover project')
    project.pin!
    collection = create_collection!(@user, name: 'Popover collection')
    collection.bucket.pin!

    get pinned_index_path, headers: { 'Turbo-Frame' => 'pinned_list' }

    assert_select 'turbo-frame#pinned_list[popover].pinned--dropdown' do
      assert_select '.layout--list-item', minimum: 3
      assert_select '.layout--list-item', text: /Pinned bullet/, count: 1
      assert_select '.layout--list-item a[href=?]', project_path(project)
      assert_select '.layout--list-item a[href=?]', bucket_path(collection.bucket)
    end
  end
end
