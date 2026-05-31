# frozen_string_literal: true

require "test_helper"

class BucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show returns success" do
    get buckets_path
    assert_response :success
  end

  test "show renders pin button for each bucket" do
    project = create_project!(@user, name: "alpha")
    collection = create_collection!(@user, name: "reading")

    get buckets_path

    assert_select "form[action=?][method=post]", buckets_pin_path do
      assert_select "input[name=bucket_ids][value=?]", project.bucket.id.to_s
    end
    assert_select "form[action=?][method=post]", buckets_pin_path do
      assert_select "input[name=bucket_ids][value=?]", collection.bucket.id.to_s
    end
  end
end
