# frozen_string_literal: true

require "test_helper"

class BucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index returns success" do
    get buckets_path
    assert_response :success
  end

  test "index renders pin button for each bucket" do
    project = create_project!(@user, name: "alpha")
    collection = create_collection!(@user, name: "reading")

    get buckets_path

    assert_select "form[action=?][method=post]", buckets_pin_path do
      assert_select "input[name=bucket_id][value=?]", project.bucket.id.to_s
    end
    assert_select "form[action=?][method=post]", buckets_pin_path do
      assert_select "input[name=bucket_id][value=?]", collection.bucket.id.to_s
    end
  end

  test "show loads bucket bullets for footer popover" do
    project = create_project!(@user, name: "bucket list")
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "In bucket",
      bucket: project.bucket,
      pops_on: Date.current
    )

    get bucket_path(project.bucket), headers: { "Turbo-Frame" => dom_id(project.bucket, :footer_bullets) }
    assert_select "turbo-frame##{dom_id(project.bucket, :footer_bullets)}[popover].pinned--list" do
      assert_select ".dropdown--header h2", text: "bucket list"
      assert_select ".bullet", text: /In bucket/, count: 1
    end
  end

  test "show returns not found for another users bucket" do
    other_user = users(:two)
    project = create_project!(other_user, name: "private")

    get bucket_path(project.bucket), headers: { "Turbo-Frame" => dom_id(project.bucket, :footer_bullets) }
    assert_response :not_found
  end
end
