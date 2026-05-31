# frozen_string_literal: true

require "test_helper"

class Bullets::CompletesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = @user.bullets.create!(bulletable: Task.create!, content: "Finish me")
  end

  test "create replaces every bullet instance via turbo stream" do
    post bullet_complete_path(@bullet),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert @bullet.reload.bulletable.done?
    assert_match "targets=\"##{dom_id(@bullet)}\"", response.body
    assert_match 'data-task-done="true"', response.body
  end

  test "destroy replaces every bullet instance via turbo stream" do
    @bullet.bulletable.complete!

    delete bullet_complete_path(@bullet),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_not @bullet.reload.bulletable.done?
    assert_match "targets=\"##{dom_id(@bullet)}\"", response.body
    assert_match 'data-task-done="false"', response.body
  end
end
