# frozen_string_literal: true

require 'test_helper'

class BundlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @collection = create_collection!(@user, name: 'Test Collection')
  end

  test 'new renders bundle form within collection' do
    get new_collection_bundle_path(@collection)
    assert_response :success
    assert_select 'form[action=?]', collection_bundles_path(@collection)
    assert_select 'select[name="bundle[collection_id]"]', count: 0
  end

  test 'new renders bundle form standalone' do
    get new_bundle_path
    assert_response :success
    assert_select 'form[action=?]', bundles_path
    assert_select 'select[name="bundle[collection_id]"]'
  end

  test 'create bundle with valid params within collection' do
    assert_difference -> { Bundle.count }, 1 do
      post collection_bundles_path(@collection),
           params: { bundle: { name: 'My Bundle', colour: 'teal' } }
    end

    assert_redirected_to collection_path(@collection)
    bundle = Bundle.last
    assert_equal 'my bundle', bundle.name
    assert_equal @collection, bundle.collection
  end

  test 'create standalone bundle with valid params' do
    assert_difference -> { Bundle.count }, 1 do
      post bundles_path,
           params: { bundle: { name: 'Standalone Bundle', colour: 'teal' } }
    end

    assert_redirected_to bundle_path(Bundle.last)
    bundle = Bundle.last
    assert_equal 'standalone bundle', bundle.name
    assert_nil bundle.collection
  end

  test 'create standalone bundle assigned to collection' do
    assert_difference -> { Bundle.count }, 1 do
      post bundles_path,
           params: { bundle: { name: 'Assigned Bundle', colour: 'teal', collection_id: @collection.id } }
    end

    bundle = Bundle.last
    assert_equal @collection, bundle.collection
    assert_redirected_to collection_path(@collection)
  end

  test 'create bundle with invalid params re-renders form' do
    assert_no_difference -> { Bundle.count } do
      post collection_bundles_path(@collection),
           params: { bundle: { name: '' } }
    end

    assert_response :unprocessable_entity
    assert_select 'form'
  end

  test 'show renders bundle bullets within collection' do
    bundle = create_bundle!(@user, @collection, name: 'Subfolder')
    BulletCreator.new(@user, { body: 'Inside bundle', bulletable_type: 'Task', bucket_id: bundle.bucket.id }).call

    get collection_bundle_path(@collection, bundle)
    assert_response :success
    assert_select '.bullet', text: /Inside bundle/
  end

  test 'show renders standalone bundle bullets' do
    bundle = create_bundle!(@user, nil, name: 'Standalone')
    BulletCreator.new(@user, { body: 'Inside standalone', bulletable_type: 'Task', bucket_id: bundle.bucket.id }).call

    get bundle_path(bundle)
    assert_response :success
    assert_select '.bullet', text: /Inside standalone/
  end

  test 'destroy deletes bundle within collection' do
    bundle = create_bundle!(@user, @collection, name: 'To delete')

    assert_difference -> { Bundle.count }, -1 do
      delete collection_bundle_path(@collection, bundle)
    end

    assert_redirected_to collection_path(@collection)
  end

  test 'destroy deletes standalone bundle' do
    bundle = create_bundle!(@user, nil, name: 'To delete standalone')

    assert_difference -> { Bundle.count }, -1 do
      delete bundle_path(bundle)
    end

    assert_redirected_to home_path
  end
end
