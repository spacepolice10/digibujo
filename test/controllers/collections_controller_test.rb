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
        collection: { name: 'Inbox', colour: 'teal', icon: 'book' }
      }
    end

    activity = Activity.order(:created_at).last
    assert_equal 'created', activity.action
    assert_equal 'Bucket', activity.subject_type
    assert_equal 'Collection', activity.metadata['bucketable_type']
    assert_redirected_to collection_path(Collection.last)
  end

  test 'new with bullet_ids renders full page form and preview' do
    card = @user.bullets.create!(bulletable: Task.create!, body: 'Preview me')

    get new_collection_path, params: { bullet_ids: card.id.to_s, return_to: review_path }

    assert_response :success
    assert_select '.layout--page.form--page'
    assert_select 'input[name="bullet_ids"][value=?]', card.id.to_s
    assert_match 'Preview me', response.body
    assert_match '1 bullet will be added', response.body
  end

  test 'create with bullet_ids collects bullets and returns turbo stream' do
    first = @user.bullets.create!(bulletable: Task.create!, body: 'One')
    second = @user.bullets.create!(bulletable: Note.create!, body: 'Two')

    assert_difference -> { Collection.count }, 1 do
      post collections_path,
           params: {
             collection: { name: 'Fresh inbox', colour: 'teal', icon: 'book' },
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
    card = @user.bullets.create!(bulletable: Task.create!, body: 'Move me')

    post collections_path,
         params: {
           collection: { name: 'Return path', colour: 'teal', icon: 'book' },
           bullet_ids: card.id.to_s,
           return_to: review_path
         }

    assert_redirected_to review_path
    assert_equal Collection.last.bucket.id, card.reload.bucket_id
  end

  test 'create with invalid collection and bullet_ids re-renders full page form' do
    card = @user.bullets.create!(bulletable: Task.create!, body: 'Hold')

    assert_no_difference -> { Collection.count } do
      post collections_path,
           params: {
             collection: { name: '', colour: 'teal', icon: 'book' },
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

  test 'destroy archives collection and hides it from active lists' do
    collection = create_collection!(@user, name: 'Old inbox')
    card = @user.bullets.create!(bulletable: Task.create!, body: 'Stay', bucket_id: collection.bucket.id)

    assert_no_difference -> { Collection.count } do
      delete collection_path(collection)
    end

    assert_redirected_to home_path
    assert collection.bucket.reload.archived?
    assert_equal collection.bucket.id, card.reload.bucket_id
    assert_empty Collection.joins(:bucket).where(buckets: { user_id: @user.id, archived: false }).where(collections: { id: collection.id })
  end
end
