# frozen_string_literal: true

require 'test_helper'

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'create saves the collection and redirects to its daylog' do
    assert_difference -> { Collection.count }, 1 do
      post collections_path, params: {
        collection: { name: 'Inbox', colour: 'teal', icon: 'folder', description: 'Things to sort' }
      }
    end

    assert_equal 'Things to sort', Collection.last.description
    assert_redirected_to bullets_path(collection: Collection.last.name)
  end

  test 'new with bullet_ids renders full page form and preview' do
    card = create_bullet!(@user, body: 'Preview me')

    get new_collection_path, params: { bullet_ids: card.id.to_s, return_to: search_path }

    assert_response :success
    assert_select 'main[data-size="sm"]'
    assert_select 'main a[aria-label="Back to Search"]', count: 0
    assert_select 'nav.tabbar--back a.tabbar--back-link[href=?][aria-label=?]', search_path, 'Back to Search', text: 'Back'
    assert_select 'form.form button[type="submit"][data-intent="primary"]', text: 'Create and collect'
    assert_select 'input[name="bullet_ids"][value=?]', card.id.to_s
    assert_match 'Preview me', response.body
    assert_match '1 bullet will be added', response.body
  end

  test 'create with bullet_ids collects bullets and redirects' do
    first = create_bullet!(@user, body: 'One')
    second = create_bullet!(@user, body: 'Two')

    assert_difference -> { Collection.count }, 1 do
      post collections_path,
           params: {
             collection: { name: 'Fresh inbox', colour: 'teal', icon: 'folder' },
             bullet_ids: "#{first.id},#{second.id}"
           }
    end

    collection = Collection.last
    assert_redirected_to bullets_path(collection: collection.name)
    assert_includes first.reload.collection_ids, collection.id
    assert_includes second.reload.collection_ids, collection.id
  end

  test 'create with bullet_ids redirects back to return_to' do
    card = create_bullet!(@user, body: 'Move me')

    post collections_path,
         params: {
           collection: { name: 'Return path', colour: 'teal', icon: 'folder' },
           bullet_ids: card.id.to_s,
           return_to: search_path
         }

    assert_redirected_to search_path
    assert_includes card.reload.collection_ids, Collection.last.id
  end

  test 'create with invalid collection and bullet_ids re-renders full page form' do
    card = create_bullet!(@user, body: 'Hold')

    assert_no_difference -> { Collection.count } do
      post collections_path,
           params: {
             collection: { name: '', colour: 'teal', icon: 'folder' },
             bullet_ids: card.id.to_s,
             return_to: search_path
           }
    end

    assert_response :unprocessable_entity
    assert_empty card.reload.collections
    assert_select 'main[data-size="sm"]'
    assert_match 'Create and collect', response.body
    assert_match 'Hold', response.body
  end

  test 'filtered daylog lists a bullet collected into the collection' do
    collection = create_collection!(@user, name: 'Inbox', colour: 'teal')
    bullet = create_bullet!(@user, body: 'Collected in', pops_on: Date.current)
    bullet.collect!(collection_id: collection.id)

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_select "turbo-frame##{dom_id(bullet)}" do
      assert_select '.bullet--marker', count: 1
      assert_select 'label.bullet--select-checkbox[aria-label=?]', 'Select bullet', count: 1
      assert_select '[popover]', count: 0
    end
    assert_no_match 'Moved into inbox.', response.body
  end

  test 'filtered daylog mounts the chat composer scoped to the collection' do
    collection = create_collection!(@user, name: 'Inbox')

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(collection, :bullets_composer)}" do
      assert_select 'lexxy-editor[preset=default]'
      assert_select "input[name='bullet[collection_id]'][value=?]", collection.id.to_s
      assert_select "input[name='bullet[file]'][type='file']"
      assert_select "input[name='bullet[bulletable_type]']", count: 0
    end
  end

  test 'filtered daylog renders the chat frame with title and actions dropdown' do
    collection = create_collection!(@user, name: 'Inbox', colour: 'teal', icon: 'folder')

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_select '.chat--window'
    assert_select '.chat--window > .chat--scroller'
    assert_select 'h1', text: /inbox/
    assert_select '.chat--window[style*=?]', '--collection-bg: var(--model-color-3-bg)'
    assert_select 'button[popovertarget="collection_actions"]'
    assert_select 'div#collection_actions[role=menu][data-controller=grid-navigation]'
    assert_select 'a.dropdown-item[href=?]', edit_collection_path(collection)
    assert_select 'a.dropdown-item[href=?]', export_bullets_path(collection: collection.name)
  end

  test 'filtered daylog groups tagged bullets into timeline sections' do
    collection = create_collection!(@user, name: 'Inbox')

    create_bullet!(@user, collection: collection, body: 'Older day', pops_on: Date.current - 2)
    create_bullet!(@user, collection: collection, body: 'Yesterday', pops_on: Date.current - 1)
    create_bullet!(@user, body: 'Untagged', pops_on: Date.current - 1)
    create_bullet!(@user, collection: collection, body: 'Today', pops_on: Date.current)

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_match 'Older day', response.body
    assert_match 'Yesterday', response.body
    assert_match 'Today', response.body
    assert_no_match 'Untagged', response.body
  end

  test 'update changes collection attributes and description' do
    collection = create_collection!(@user, name: 'Old name', colour: 'teal', icon: 'folder')
    collection.update!(description: 'Original')

    patch collection_path(collection), params: {
      collection: { name: 'New name', colour: 'gold', icon: 'heart', description: 'Updated' }
    }

    assert_redirected_to bullets_path(collection: 'new name')
    collection.reload
    assert_equal 'new name', collection.name
    assert_equal 'Updated', collection.description
    assert_equal 'gold', collection.colour
    assert_equal 'heart', collection.icon
  end

  test 'destroy archives collection and hides it from active lists' do
    collection = create_collection!(@user, name: 'Old inbox')
    card = create_bullet!(@user, body: 'Stay', collection: collection)

    assert_no_difference -> { Collection.count } do
      delete collection_path(collection)
    end

    assert_redirected_to search_path
    assert collection.reload.archived?
    assert_includes card.reload.collection_ids, collection.id
    assert_empty @user.collections.active.where(id: collection.id)
  end
end
