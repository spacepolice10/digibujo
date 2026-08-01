# frozen_string_literal: true

require 'test_helper'

module Reviews
  class CollectionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @today = Date.current
    end

    test 'index lists active collections' do
      create_collection!(@user, name: 'Work')
      create_collection!(@user, name: 'Personal')

      get review_collections_path(from: @today.iso8601, to: @today.iso8601)

      assert_response :success
      assert_select '.collection--section-list-item', minimum: 2
      assert_select '.utilities--line-clamp-1', text: 'work'
      assert_select '.utilities--line-clamp-1', text: 'personal'
    end

    test 'index searches collections by name' do
      create_collection!(@user, name: 'Work inbox')
      create_collection!(@user, name: 'Personal notes')

      get review_collections_path(from: @today.iso8601, to: @today.iso8601, q: 'work')

      assert_response :success
      assert_select '.utilities--line-clamp-1', text: 'work inbox'
      assert_select '.utilities--line-clamp-1', text: 'personal notes', count: 0
    end

    test 'index paginates collections' do
      25.times { |i| create_collection!(@user, name: "Collection #{i}") }

      get review_collections_path(from: @today.iso8601, to: @today.iso8601)

      assert_response :success
      assert_select '.pagination-trigger'
    end

    test 'index responds to turbo_stream for live search' do
      create_collection!(@user, name: 'Searchable')

      get review_collections_path(from: @today.iso8601, to: @today.iso8601, q: 'search'),
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_select 'turbo-stream[action="replace"][target="paginated-review-collections"]'
    end

    test 'index requires authentication' do
      sign_out
      get review_collections_path(from: @today.iso8601, to: @today.iso8601)
      assert_redirected_to new_authentication_path
    end
  end
end
