# frozen_string_literal: true

require 'test_helper'

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'create records bucket created activity' do
    assert_difference -> { Activity.count }, 1 do
      post collections_path, params: {
        collection: { name: 'Inbox', colour: 'teal', icon: 'folder', description: 'Things to sort' }
      }
    end

    activity = Activity.order(:created_at).last
    assert_equal 'created', activity.action
    assert_equal 'Bucket', activity.subject_type
    assert_equal 'Collection', activity.metadata['bucketable_type']
    assert_equal 'Things to sort', Collection.last.description
    assert_redirected_to collection_path(Collection.last)
  end

  test 'new with bullet_ids renders full page form and preview' do
    card = create_bullet!(@user, bulletable: Task.new(body: 'Preview me'))

    get new_collection_path, params: { bullet_ids: card.id.to_s, return_to: review_path }

    assert_response :success
    assert_select '.layout--page.form--page'
    assert_select 'input[name="bullet_ids"][value=?]', card.id.to_s
    assert_match 'Preview me', response.body
    assert_match '1 bullet will be added', response.body
  end

  test 'create with bullet_ids collects bullets and returns turbo stream' do
    first = create_bullet!(@user, bulletable: Task.new(body: 'One'))
    second = create_bullet!(@user, bulletable: Note.new(body: 'Two'))

    assert_difference -> { Collection.count }, 1 do
      post collections_path,
           params: {
             collection: { name: 'Fresh inbox', colour: 'teal', icon: 'folder' },
             bullet_ids: "#{first.id},#{second.id}"
           },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end

    collection = Collection.last
    assert_equal collection.bucket.id, first.reload.bucket_id
    assert_equal collection.bucket.id, second.reload.bucket_id
    assert first.migrated?
    assert second.migrated?
    assert_match %(turbo-stream action="remove" targets="#bullet_#{first.id}"), response.body
    assert_match %(turbo-stream action="remove" targets="#bullet_#{second.id}"), response.body
  end

  test 'create with bullet_ids redirects back to return_to' do
    card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))

    post collections_path,
         params: {
           collection: { name: 'Return path', colour: 'teal', icon: 'folder' },
           bullet_ids: card.id.to_s,
           return_to: review_path
         }

    assert_redirected_to review_path
    assert_equal Collection.last.bucket.id, card.reload.bucket_id
  end

  test 'create with invalid collection and bullet_ids re-renders full page form' do
    card = create_bullet!(@user, bulletable: Task.new(body: 'Hold'))

    assert_no_difference -> { Collection.count } do
      post collections_path,
           params: {
             collection: { name: '', colour: 'teal', icon: 'folder' },
             bullet_ids: card.id.to_s,
             return_to: review_path
           }
    end

    assert_response :unprocessable_entity
    assert_nil card.reload.bucket_id
    assert_select '.layout--page.form--page'
    assert_match 'Create and collect', response.body
    assert_match 'Hold', response.body
  end

  test 'show renders collected migration hint when bullet was collected into the collection' do
    collection = create_collection!(@user, name: 'Inbox', colour: 'teal')
    bullet = create_bullet!(@user, bulletable: Task.new(body: 'Collected in'), pops_on: Date.current)
    bullet.collect!(bucket_id: collection.bucket.id)

    get collection_path(collection)

    assert_response :success
    assert_select '.bullet--metadata button[aria-label=?]', 'Collected', minimum: 1
    assert_match 'Moved into Inbox.', response.body
  end

  test 'show renders composer create buttons for all bullet types' do
    collection = create_collection!(@user, name: 'Inbox')

    get collection_path(collection)

    assert_response :success
    assert_select 'a[aria-label=?]', 'Add Note' do
      assert_select '[href=?]', new_bullet_path(
        bulletable_type: 'Note', bucket_id: collection.bucket.id, pops_on: nil
      )
    end
    assert_select '.bullets-form--dock a.bullets-form--create-button', count: 4
  end

  test 'update changes bucket attributes and description' do
    collection = create_collection!(@user, name: 'Old name', colour: 'teal', icon: 'folder')
    collection.update!(description: 'Original')

    patch collection_path(collection), params: {
      collection: { name: 'New name', colour: 'gold', icon: 'heart', description: 'Updated' }
    }

    assert_redirected_to collection_path(collection)
    collection.reload
    assert_equal 'new name', collection.name
    assert_equal 'Updated', collection.description
    assert_equal 'gold', collection.bucket.colour
    assert_equal 'heart', collection.bucket.icon
  end

  test 'destroy archives collection and hides it from active lists' do
    collection = create_collection!(@user, name: 'Old inbox')
    card = create_bullet!(@user, bulletable: Task.new(body: 'Stay'), bucket_id: collection.bucket.id, pops_on: nil)

    assert_no_difference -> { Collection.count } do
      delete collection_path(collection)
    end

    assert_redirected_to home_path
    assert collection.bucket.reload.archived?
    assert_equal collection.bucket.id, card.reload.bucket_id
    assert_empty @user.collections.merge(Bucket.active).where(collections: { id: collection.id })
  end
end
