# frozen_string_literal: true

require "test_helper"

class BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = @user.bullets.create!(bulletable: Task.create!, content: "Original")
  end

  test "update turbo stream replaces bullet only" do
    assert_difference -> { BulletActivity.count }, 1 do
      patch bullet_path(@bullet),
            params: { bullet: { content: "Updated" } },
            as: :turbo_stream
    end

    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_no_match(/turbo-stream action="after"/, response.body)
    assert_equal "Updated", @bullet.reload.content.to_plain_text
    assert_equal 'updated', BulletActivity.order(:created_at).last.action
  end

  test "create turbo stream appends bullet and inserts form after" do
    post bullets_path,
         params: {
           bullet: { bulletable_type: "Task", content: "Fresh task" },
           date: Date.current.iso8601
         },
         as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream action="append"/, response.body)
    assert_match(/turbo-stream action="after"/, response.body)
  end
end
