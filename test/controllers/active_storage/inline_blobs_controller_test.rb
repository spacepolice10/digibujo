# frozen_string_literal: true

require "test_helper"

module ActiveStorage
  class InlineBlobsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as users(:one)
      @blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")),
        filename: "photo.png",
        content_type: "image/png"
      )
    end

    test "show renders inline blob partial" do
      host! "www.example.com"

      get active_storage_inline_blob_path(@blob.signed_id)

      assert_response :success
      assert_select "span.attachment.attachment--preview.attachment--inline", count: 1
      assert_select "img.attachment--preview-image", count: 1
    end
  end
end
