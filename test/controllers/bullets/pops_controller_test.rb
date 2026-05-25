# frozen_string_literal: true

require "test_helper"

class Bullets::PopsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create redirects to daylog and sets pop day" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Plan me")
    target = 3.days.from_now.to_date

    post bullet_pop_path(card), params: { pops_on: target.iso8601 }

    assert_redirected_to daylog_path_to(target)
    assert_equal target, card.reload.pops_on
  end

  test "create ignores bucket_id" do
    project = create_project!(@user, name: "Deep work")
    card = @user.bullets.create!(bulletable: Event.create!, content: "Workshop")
    target = 1.week.from_now.to_date

    post bullet_pop_path(card), params: { pops_on: target.iso8601, bucket_id: project.bucket.id }

    assert_redirected_to daylog_path_to(target)
    assert_equal target, card.reload.pops_on
    assert_nil card.bucket_id
  end

  test "create with pops_on one day ahead acts as postpone from bullet pop day" do
    anchor = 5.days.from_now.to_date
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Defer me",
      pops_on: anchor
    )

    post bullet_pop_path(card), params: { pops_on: (anchor + 1.day).iso8601 }

    assert_redirected_to daylog_path_to(anchor + 1.day)
    assert_equal anchor + 1.day, card.reload.pops_on
  end

  test "create with pops_on from daylog viewing day acts as postpone from that anchor" do
    view_day = Date.current
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Triage",
      pops_on: 2.weeks.from_now.to_date
    )

    post bullet_pop_path(card), params: { pops_on: (view_day + 1.day).iso8601 }

    assert_redirected_to daylog_path_to(view_day + 1.day)
    assert_equal view_day + 1.day, card.reload.pops_on
  end

  test "create with pops_on one week ahead" do
    view_day = Date.current
    card = @user.bullets.create!(bulletable: Event.create!, content: "Later", pops_on: nil)

    post bullet_pop_path(card), params: { pops_on: (view_day + 1.week).iso8601 }

    assert_redirected_to daylog_path_to(view_day + 1.week)
    assert_equal view_day + 1.week, card.reload.pops_on
  end

  test "destroy clears pops_on" do
    target = 2.days.from_now.to_date
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Clear day",
      pops_on: target
    )

    delete bullet_pop_path(card)

    assert_redirected_to daylog_path_to(target)
    assert_nil card.reload.pops_on
  end
end
