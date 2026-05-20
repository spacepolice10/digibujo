# frozen_string_literal: true

require "test_helper"

class Bullets::SchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create redirects to bullets and sets scheduled day" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Plan me")
    target = 3.days.from_now.to_date

    post bullet_schedule_path(card), params: { scheduled_on: target.iso8601 }

    assert_redirected_to bullets_path
    assert_equal target, card.reload.scheduled_on
  end

  test "create assigns bucket when params include bucket_id" do
    project = create_project!(@user, name: "Deep work")
    card = @user.bullets.create!(bulletable: Event.create!, content: "Workshop")
    target = 1.week.from_now.to_date

    post bullet_schedule_path(card), params: { scheduled_on: target.iso8601, bucket_id: project.bucket.id }

    assert_redirected_to bullets_path
    card.reload
    assert_equal target, card.scheduled_on
    assert_equal project.bucket, card.reload.bucket
  end
end
