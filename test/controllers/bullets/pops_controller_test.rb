# frozen_string_literal: true

require "test_helper"

class Bullets::PopsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create redirects to bullets and sets pop day" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Plan me")
    target = 3.days.from_now.to_date

    post bullet_pop_path(card), params: { pops_on: target.iso8601 }

    assert_redirected_to daylog_path
    assert_equal target, card.reload.pops_on
  end

  test "create ignores bucket_id" do
    project = create_project!(@user, name: "Deep work")
    card = @user.bullets.create!(bulletable: Event.create!, content: "Workshop")
    target = 1.week.from_now.to_date

    post bullet_pop_path(card), params: { pops_on: target.iso8601, bucket_id: project.bucket.id }

    assert_redirected_to daylog_path
    assert_equal target, card.reload.pops_on
    assert_nil card.bucket_id
  end

  test "postpone_next_day advances from bullet pop day" do
    anchor = 5.days.from_now.to_date
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Defer me",
      pops_on: anchor
    )

    post postpone_next_day_bullet_pop_path(card)

    assert_redirected_to daylog_path
    assert_equal anchor + 1.day, card.reload.pops_on
  end

  test "postpone_next_day uses display_on as anchor when viewing a timeline day" do
    view_day = Date.current
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Triage",
      pops_on: 2.weeks.from_now.to_date
    )

    post postpone_next_day_bullet_pop_path(card), params: { display_on: view_day.iso8601 }

    assert_redirected_to daylog_path
    assert_equal view_day + 1.day, card.reload.pops_on
  end

  test "postpone_next_week advances one week from anchor" do
    view_day = Date.current
    card = @user.bullets.create!(bulletable: Event.create!, content: "Later", pops_on: nil)

    post postpone_next_week_bullet_pop_path(card), params: { display_on: view_day.iso8601 }

    assert_redirected_to daylog_path
    assert_equal view_day + 1.week, card.reload.pops_on
  end

  test "destroy clears pops_on" do
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Clear day",
      pops_on: 2.days.from_now.to_date
    )

    delete bullet_pop_path(card)

    assert_redirected_to daylog_path
    assert_nil card.reload.pops_on
  end
end
