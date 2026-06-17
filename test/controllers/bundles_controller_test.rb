# frozen_string_literal: true

require 'test_helper'

class BundlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @collection = create_collection!(@user, name: 'Test Collection')
  end

  test 'new renders bundle form' do
    get new_collection_bundle_path(@collection)
    assert_response :success
    assert_select 'form[action=?]', collection_bundles_path(@collection)
  end

  test 'create bundle with valid params' do
    assert_difference -> { Bundle.count }, 1 do
      post collection_bundles_path(@collection),
           params: { bundle: { name: 'My Bundle', colour: 'blue' } }
    end

    assert_redirected_to collection_path(@collection)
    bundle = Bundle.last
    assert_equal 'My Bundle', bundle.name
  end

  test 'create bundle with invalid params re-renders form' do
    assert_no_difference -> { Bundle.count } do
      post collection_bundles_path(@collection),
           params: { bundle: { name: '' } }
    end

    assert_response :unprocessable_entity
    assert_select 'form'
  end

  test 'show renders bundle bullets' do
    bundle = create_bundle!(@user, @collection, name: 'Subfolder')
    BulletCreator.new(@user, { body: 'Inside bundle', bulletable_type: 'Task', bucket_id: bundle.bucket.id }).call

    get collection_bundle_path(@collection, bundle)
    assert_response :success
    assert_select '.bullet', text: /Inside bundle/
  end

  test 'destroy deletes bundle' do
    bundle = create_bundle!(@user, @collection, name: 'To delete')

    assert_difference -> { Bundle.count }, -1 do
      delete collection_bundle_path(@collection, bundle)
    end

    assert_redirected_to collection_path(@collection)
  end
end
