# frozen_string_literal: true

require "test_helper"

class Bullets::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = @user.bullets.create!(bulletable: Task.create!, content: "Pin me")
  end

  test "update pins bullet and refreshes dock via turbo stream" do
    patch bullet_pin_path(@bullet), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert @bullet.reload.pinned?
    assert_match "turbo-stream", response.media_type
    assert_match "pinned_bullets_dock", response.body
  end

  test "update unpins bullet via turbo stream" do
    @bullet.update!(pinned: true)

    patch bullet_pin_path(@bullet), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_not @bullet.reload.pinned?
  end

  test "update rejects pin when limit exceeded" do
    Pinnable::PIN_LIMIT.times do |i|
      @user.bullets.create!(bulletable: Task.create!, content: "Pinned #{i}", pinned: true)
    end

    patch bullet_pin_path(@bullet), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
    assert_not @bullet.reload.pinned?
  end
end
