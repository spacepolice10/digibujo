# frozen_string_literal: true

require "test_helper"

class MonthlylogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "monthlylog shows empty when no spread covers current month" do
    get monthlylog_path

    assert_response :success
    assert_match "No monthly log covers", response.body
  end

  test "monthlylog shows spread when current monthlylog exists" do
    monthlylog = create_monthlylog!(@user, name: "june")
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "Unplanned task",
      bucket_id: monthlylog.bucket.id
    )

    get monthlylog_path

    assert_response :success
    assert_match "Unplanned task", response.body
    assert_match "Unplanned", response.body
  end

  test "show by id lists dated bullets in by_date column" do
    monthlylog = create_monthlylog!(@user, name: "june")
    day = Date.current.beginning_of_month + 2.days
    @user.bullets.create!(
      bulletable: Event.create!,
      content: "Dentist",
      bucket_id: monthlylog.bucket.id,
      pops_on: day
    )

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_match "Dentist", response.body
  end

  test "create duplicate month returns unprocessable entity" do
    create_monthlylog!(@user, name: "june")
    period = Bucket.monthlylog_period

    assert_no_difference "Monthlylog.count" do
      post monthlylogs_path, params: {
        monthlylog: {
          name: "june again",
          period_from: period[:period_from].iso8601,
          period_to: period[:period_to].iso8601
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "already exists", response.body
  end

  test "new form defaults to current month period" do
    get new_monthlylog_path

    assert_response :success
    assert_select "input[name='monthlylog[period_from]'][value=?]", Date.current.beginning_of_month.iso8601
    assert_select "input[name='monthlylog[period_to]'][value=?]", Date.current.end_of_month.iso8601
  end
end
