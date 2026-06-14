# frozen_string_literal: true

require "test_helper"

class Bullets::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = @user.bullets.create!(bulletable: Task.create!, content: "Pin me")
  end

  test "create pins bullet and renders dock via turbo stream" do
    post pin_path,
         params: { bullet_ids: @bullet.id.to_s },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert @bullet.reload.pinned?
    assert_match "turbo-stream", response.media_type
    assert_match "pinned_bullets_dock", response.body
  end

  test "create updates dock frame when dock already has pins" do
    existing = @user.bullets.create!(bulletable: Task.create!, content: "Already pinned")
    PinnedEntity.create!(user: @user, pinnable: existing)

    post pin_path,
         params: { bullet_ids: @bullet.id.to_s },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert @bullet.reload.pinned?
    assert_match "pinned_bullets_dock", response.body
    assert_match "popovertarget=\"pinned_bullets\"", response.body
    assert_match "popover", response.body
    assert_match "loading=\"lazy\"", response.body
    assert_no_match "pinned--dock-item", response.body
  end

  test "create pins multiple bullets" do
    other = @user.bullets.create!(bulletable: Note.create!, content: "Too")

    post pin_path, params: { bullet_ids: "#{@bullet.id},#{other.id}" }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert @bullet.reload.pinned?
    assert other.reload.pinned?
  end

  test "destroy unpins bullet and updates dock frame via turbo stream" do
    @user.bullets.create!(bulletable: Task.create!, content: "Still pinned")
    @bullet.pin!

    delete pin_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_not @bullet.reload.pinned?
    assert_match "pinned_bullets_dock", response.body
    assert_match "popovertarget=\"pinned_bullets\"", response.body
    assert_match "popover", response.body
    assert_match "loading=\"lazy\"", response.body
    assert_no_match "pinned--dock-item", response.body
  end

  test "create turbo stream replaces monthly bucket bullet with unified row" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Spread task",
      bucket_id: monthly_bucket.bucket.id
    )

    post pin_path,
         params: { bullet_ids: bullet.id.to_s },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert bullet.reload.pinned?
    assert_match %(turbo-stream action="replace" target="bullet_#{bullet.id}"), response.body
    assert_match "bullet--marker-slot", response.body
    assert_match "bullet--body", response.body
    assert_no_match "bullet-compact", response.body
  end

  test "destroy clears dock when last pin is removed" do
    @bullet.pin!

    delete pin_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_not @bullet.reload.pinned?
    assert_match "pinned_bullets_dock", response.body
  end
end
