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
    card = create_bullet!(@user, bulletable: Task.new, body: 'Preview me')

    get new_collection_path, params: { bullet_ids: card.id.to_s, return_to: review_path }

    assert_response :success
    assert_select '.layout--container[data-size="md"]'
    assert_select 'input[name="bullet_ids"][value=?]', card.id.to_s
    assert_match 'Preview me', response.body
    assert_match '1 bullet will be added', response.body
  end

  test 'create with bullet_ids collects bullets and redirects' do
    first = create_bullet!(@user, bulletable: Task.new, body: 'One')
    second = create_bullet!(@user, bulletable: Note.new, body: 'Two')

    assert_difference -> { Collection.count }, 1 do
      post collections_path,
           params: {
             collection: { name: 'Fresh inbox', colour: 'teal', icon: 'folder' },
             bullet_ids: "#{first.id},#{second.id}"
           }
    end

    collection = Collection.last
    assert_redirected_to collection_path(collection)
    assert_equal collection.bucket.id, first.reload.bucket_id
    assert_equal collection.bucket.id, second.reload.bucket_id
    assert first.migrated?
    assert second.migrated?
  end

  test 'create with bullet_ids redirects back to return_to' do
    card = create_bullet!(@user, bulletable: Task.new, body: 'Move me')

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
    card = create_bullet!(@user, bulletable: Task.new, body: 'Hold')
    daylog_bucket_id = card.bucket_id

    assert_no_difference -> { Collection.count } do
      post collections_path,
           params: {
             collection: { name: '', colour: 'teal', icon: 'folder' },
             bullet_ids: card.id.to_s,
             return_to: review_path
           }
    end

    assert_response :unprocessable_entity
    assert_equal daylog_bucket_id, card.reload.bucket_id
    assert_select '.layout--container[data-size="md"]'
    assert_match 'Create and collect', response.body
    assert_match 'Hold', response.body
  end

  test 'show renders collected migration hint when bullet was collected into the collection' do
    collection = create_collection!(@user, name: 'Inbox', colour: 'teal')
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Collected in', pops_on: Date.current)
    bullet.collect!(bucket_id: collection.bucket.id)

    get collection_path(collection)

    assert_response :success
    assert_select "turbo-frame##{dom_id(bullet)}" do
      assert_select '.bullet--marker[style*="--bullet-type-color: var(--model-color-2)"]', count: 1
      assert_select '.bullet--marker-migration', count: 1
      assert_select 'label.bullet--select-checkbox[aria-label=?]', 'Select bullet', count: 1
      assert_select '[popover]', count: 0
    end
    assert_no_match 'Moved into inbox.', response.body
  end

  test 'show mounts the chat composer scoped to the collection bucket' do
    collection = create_collection!(@user, name: 'Inbox')

    get collection_path(collection)

    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(collection, :bullets_composer)}" do
      assert_select 'lexxy-editor[preset=default]'
      assert_select "input[name='bullet[bucket_id]'][value=?]", collection.bucket.id.to_s
      assert_select "select[name='bullet[bulletable_type]'] option", count: 3
      assert_select "input[name='bullet[bulletable_type]'][value=?][disabled]", 'Voice'
    end
  end

  test 'show renders the floating chat frame with frosted chips and actions dropdown' do
    collection = create_collection!(@user, name: 'Inbox', colour: 'teal', icon: 'folder')
    collection.update!(description: 'Things to sort')

    get collection_path(collection)

    assert_response :success
    assert_select '.chat--window'
    assert_select '.collection--chat-header'
    assert_select '.collection--frost-chip.collection--frost-chip--title', text: /inbox/
    assert_select '.collection--frost-chip.collection--frost-chip--description', text: /Things to sort/
    assert_select 'button[popovertarget="collection_actions"]'
    assert_select 'div#collection_actions.dropdown--element[data-controller=grid-navigation]'
    assert_select 'a.dropdown-item[href=?]', edit_collection_path(collection)
    assert_select "a.dropdown-item[href=?]", collection_export_path(collection)
  end

  test 'show omits description chip when absent' do
    collection = create_collection!(@user, name: 'Inbox')

    get collection_path(collection)

    assert_response :success
    assert_select '.collection--frost-chip--description', count: 0
  end

  test 'show inserts date pills between days and skips duplicates within a day' do
    collection = create_collection!(@user, name: 'Inbox')
    bucket = collection.bucket

    create_bullet!(@user, bucket: bucket, pops_on: nil, bulletable: Note.new, body: 'Older day',
                   created_at: 2.days.ago.change(hour: 10))
    create_bullet!(@user, bucket: bucket, pops_on: nil, bulletable: Note.new, body: 'Yesterday a',
                   created_at: 1.day.ago.change(hour: 9))
    create_bullet!(@user, bucket: bucket, pops_on: nil, bulletable: Note.new, body: 'Yesterday b',
                   created_at: 1.day.ago.change(hour: 18))
    create_bullet!(@user, bucket: bucket, pops_on: nil, bulletable: Note.new, body: 'Today',
                   created_at: Time.current.change(hour: 12))

    get collection_path(collection)

    assert_response :success
    assert_select '.collection--date-pill', count: 3
    assert_select '.collection--date-pill',
                  text: (Date.current - 2.days).strftime('%b %-d, %Y'), count: 1
    assert_select '.collection--date-pill',
                  text: (Date.current - 1.day).strftime('%b %-d, %Y'), count: 1
    assert_select '.collection--date-pill',
                  text: Date.current.strftime('%b %-d, %Y'), count: 1
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
    card = create_bullet!(@user, bulletable: Task.new, body: 'Stay', bucket_id: collection.bucket.id, pops_on: nil)

    assert_no_difference -> { Collection.count } do
      delete collection_path(collection)
    end

    assert_redirected_to home_path
    assert collection.bucket.reload.archived?
    assert_equal collection.bucket.id, card.reload.bucket_id
    assert_empty @user.collections.merge(Bucket.active).where(collections: { id: collection.id })
  end
end
