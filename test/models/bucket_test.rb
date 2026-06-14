# frozen_string_literal: true

require "test_helper"

class BucketTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @collection = create_collection!(@user, name: "alpha")
    @bucket = @collection.bucket
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
    @bucket.update!(colour: "teal", icon: "calendar")
    assert_equal "teal", @bucket.colour
    assert_equal "calendar", @bucket.icon
  end

  test "allows nil colour and icon" do
    @bucket.update!(colour: nil, icon: nil)
    assert_nil @bucket.colour
    assert_nil @bucket.icon
  end

  test "rejects invalid colour" do
    @bucket.colour = "crimson"
    assert_not @bucket.valid?
  end

  test "rejects legacy numeric colour keys" do
    @bucket.colour = "3"
    assert_not @bucket.valid?
  end

  test "rejects invalid icon" do
    @bucket.icon = "invalid"
    assert_not @bucket.valid?
  end

  test "bucketable delegates identity" do
    @bucket.update!(colour: "cobalt", icon: "pin")
    assert_equal "alpha", @collection.name
    assert_equal "cobalt", @collection.colour
    assert_equal "pin", @collection.icon
  end

  test "collection names can be duplicated per user" do
    create_collection!(@user, name: "reading")
    duplicate = Collection.create!
    bucket = @user.buckets.build(bucketable: duplicate, name: "reading")
    assert bucket.valid?
  end

  test "pin! marks bucket pinned" do
    assert_not @bucket.pinned?

    assert @bucket.pin!

    assert @bucket.reload.pinned?
  end

  test "unpin! clears pinned state" do
    @bucket.pin!

    @bucket.unpin!

    assert_not @bucket.reload.pinned?
  end

  test "collection bucket allows nil period" do
    assert @bucket.valid?
  end
end
