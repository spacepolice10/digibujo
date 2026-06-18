# frozen_string_literal: true

require 'test_helper'

class BundlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @collection = create_collection!(@user, name: 'Test Collection')
  end

  test 'new renders inline bundle form in composer frame' do
    get new_collection_bundle_path(@collection), headers: { 'Turbo-Frame' => 'bundle_composer' }

    assert_response :success
    assert_select 'turbo-frame#bundle_composer'
    assert_select 'form[action=?]', collection_bundles_path(@collection)
    assert_select 'input[name="bundle[name]"]'
    assert_select 'input[type=submit][value=?]', 'Save'
    assert_select 'a.bundle--close[aria-label=?]', 'Cancel'
    assert_select 'h3.bundle--title', text: 'New bundle'
    assert_select 'input[name="bundle[colour]"]'
  end

  test 'new with cancel clears composer frame' do
    get new_collection_bundle_path(@collection, cancel: 1), headers: { 'Turbo-Frame' => 'bundle_composer' }

    assert_response :success
    assert_select 'turbo-frame#bundle_composer'
    assert_select 'form', count: 0
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

  test 'create bundle with turbo stream prepends section and clears composer' do
    assert_difference -> { Bundle.count }, 1 do
      post collection_bundles_path(@collection),
           params: { bundle: { name: 'Inline Bundle' } },
           as: :turbo_stream
    end

    assert_response :success
    assert_turbo_stream action: 'prepend', target: 'bundle_list'
    assert_turbo_stream action: 'replace', target: 'bundle_composer'
    assert_match(/Inline Bundle/i, response.body)
  end

  test 'create bundle with invalid params re-renders inline form' do
    assert_no_difference -> { Bundle.count } do
      post collection_bundles_path(@collection),
           params: { bundle: { name: '' } },
           as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_includes response.media_type, 'turbo-stream'
    assert_match(/bundle_composer/, response.body)
    assert_match(/bundle\[name\]/, response.body)
  end

  test 'show renders bundle bullets within collection' do
    bundle = create_bundle!(@user, @collection, name: 'Subfolder')
    BulletCreator.new(@user, { body: 'Inside bundle', bulletable_type: 'Task', bucket_id: bundle.bucket.id }).call

    get collection_bundle_path(@collection, bundle)
    assert_response :success
    assert_select '.bundle--section'
    assert_select 'h2.layout--surface-title', text: /subfolder/i
    assert_select '.bundle--close'
    assert_select '.bullet-composer--add', text: /Add bullet/
    assert_select '.bullet', text: /Inside bundle/
  end

  test 'destroy deletes bundle within collection' do
    bundle = create_bundle!(@user, @collection, name: 'To delete')

    assert_difference -> { Bundle.count }, -1 do
      delete collection_bundle_path(@collection, bundle)
    end

    assert_redirected_to collection_path(@collection)
  end
end
