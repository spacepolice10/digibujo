# frozen_string_literal: true

require 'test_helper'

module Collections
  class BulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @collection = create_collection!(@user, name: 'Inbox')
      @bucket = @collection.bucket
    end

    def create_collected(body, created_at:)
      create_bullet!(@user, bucket: @bucket, pops_on: nil, bulletable: Note.new(body: body),
                            created_at: created_at)
    end

    test 'before returns an older page of bare rows' do
      create_collected('Older row', created_at: 2.days.ago)
      newer = create_collected('Newer row', created_at: 1.day.ago)

      get collection_bullets_path(@collection, before: newer.id)

      assert_response :success
      assert_match 'Older row', response.body
      assert_no_match 'Newer row', response.body
      assert_no_match 'collection--date-pill', response.body
    end

    test 'before scopes to the collection bucket' do
      create_bullet!(@user,
                     bulletable: Note.new(body: 'Other bucket'), pops_on: nil, created_at: 2.days.ago)
      cursor = create_collected('Cursor', created_at: 1.day.ago)

      get collection_bullets_path(@collection, params: { before: cursor.id })

      assert_response :success
      assert_no_match 'Other bucket', response.body
    end

    test 'before returns no content when nothing older exists' do
      cursor = create_collected('Cursor', created_at: Time.current)
      get collection_bullets_path(@collection, params: { before: cursor.id })
      assert_response :no_content
    end

    test 'before returns no content when cursor is unknown' do
      get collection_bullets_path(@collection, params: { before: 0 })
      assert_response :no_content
    end

    test 'before returns not found for a foreign collection' do
      other = create_collection!(users(:two), name: 'Theirs')
      get collection_bullets_path(other)
      assert_response :not_found
    end
  end
end
