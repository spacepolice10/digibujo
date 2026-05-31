# frozen_string_literal: true

require "test_helper"

class BucketTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = create_project!(@user, name: "alpha")
    @bucket = @project.bucket
  end

  test "requires name" do
    @bucket.name = ""
    assert_not @bucket.valid?
  end

  test "normalizes name" do
    @bucket.update!(name: "  Beta  ")
    assert_equal "beta", @bucket.name
  end

  test "accepts valid colour and icon" do
    @bucket.update!(colour: "3", icon: "calendar")
    assert_equal "3", @bucket.colour
    assert_equal "calendar", @bucket.icon
  end

  test "allows nil colour and icon" do
    @bucket.update!(colour: nil, icon: nil)
    assert_nil @bucket.colour
    assert_nil @bucket.icon
  end

  test "rejects invalid colour" do
    @bucket.colour = "9"
    assert_not @bucket.valid?
  end

  test "rejects invalid icon" do
    @bucket.icon = "invalid"
    assert_not @bucket.valid?
  end

  test "bucketable delegates identity" do
    @bucket.update!(colour: "2", icon: "pin")
    assert_equal "alpha", @project.name
    assert_equal "2", @project.colour
    assert_equal "pin", @project.icon
  end

  test "collection names are unique per user" do
    create_collection!(@user, name: "reading")
    duplicate = Collection.create!
    bucket = @user.buckets.build(bucketable: duplicate, name: "reading")
    assert_not bucket.valid?
    assert_includes bucket.errors[:name], "has already been taken"
  end

  test "project names may duplicate per user" do
    create_project!(@user, name: "alpha")
    other = Project.create!
    bucket = @user.buckets.build(bucketable: other, name: "alpha")
    assert bucket.valid?
  end

  test "pin! marks bucket pinned" do
    assert_not @bucket.pinned?

    assert @bucket.pin!

    assert @bucket.reload.pinned?
  end

  test "unpin! clears pinned state" do
    @bucket.update!(pinned: true)

    @bucket.unpin!

    assert_not @bucket.reload.pinned?
  end
end
