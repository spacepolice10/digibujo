# frozen_string_literal: true

require 'test_helper'

module Buckets
  class SideNotesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @collection = create_collection!(@user, name: 'alpha')
      @bucket = @collection.bucket
    end

    test 'update saves side note content' do
      patch bucket_side_note_path(@bucket),
            params: { bucket: { side_note: '<p>Scratch notes</p>' } }

      assert_response :no_content
      assert_includes @bucket.reload.side_note.to_plain_text, 'Scratch notes'
    end

    test 'update assigns side note html not nested params hash' do
      patch bucket_side_note_path(@bucket),
            params: { bucket: { side_note: '<p>H</p>' } }

      assert_response :no_content
      assert_equal 'H', @bucket.reload.side_note.to_plain_text.strip
      assert_no_match(/side_note/, @bucket.side_note.body.to_s)
    end

    test 'update returns not found for another users bucket' do
      other_user = users(:two)
      other_collection = create_collection!(other_user, name: 'private')

      patch bucket_side_note_path(other_collection.bucket),
            params: { bucket: { side_note: '<p>Nope</p>' } }

      assert_response :not_found
    end

    test 'update requires authentication' do
      delete session_path

      patch bucket_side_note_path(@bucket),
            params: { bucket: { side_note: '<p>Scratch notes</p>' } }

      assert_redirected_to new_session_path
    end
  end
end
