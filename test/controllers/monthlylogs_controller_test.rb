# frozen_string_literal: true

require "test_helper"

class MonthlylogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "monthlylog without date shows current month" do
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "This month",
      pops_on: Date.current.beginning_of_month + 2.days
    )

    get monthlylog_path

    assert_response :success
    assert_match "This month", response.body
  end

  test "monthlylog with year and month shows that month" do
    anchor = Date.current.beginning_of_month.prev_month
    @user.bullets.create!(bulletable: Task.create!, content: "Last month", pops_on: anchor + 1.day)
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "This month",
      pops_on: Date.current.beginning_of_month + 1.day
    )

    get monthlylog_on_path(year: anchor.year, month: anchor.month)

    assert_response :success
    assert_match "Last month", response.body
    assert_no_match "This month", response.body
  end
end
