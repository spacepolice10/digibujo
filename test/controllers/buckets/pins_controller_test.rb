# frozen_string_literal: true

require "test_helper"

class Buckets::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @project = create_project!(@user, name: "alpha")
    @bucket = @project.bucket
  end

  test "create pins bucket and updates list item via turbo stream" do
    post buckets_pin_path,
         params: { bucket_ids: @bucket.id.to_s },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert @bucket.reload.pinned?
    assert_match "turbo-stream", response.media_type
    assert_match dom_id(@bucket, :list_item), response.body
  end

  test "destroy unpins bucket and updates list item via turbo stream" do
    @bucket.update!(pinned: true)

    delete buckets_pin_path,
           params: { bucket_ids: @bucket.id.to_s },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_not @bucket.reload.pinned?
    assert_match dom_id(@bucket, :list_item), response.body
  end

  test "create redirects html requests back to buckets index" do
    post buckets_pin_path, params: { bucket_ids: @bucket.id.to_s }

    assert_redirected_to buckets_path
    assert @bucket.reload.pinned?
  end
end
