# frozen_string_literal: true

require "test_helper"

class Recurrencies::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @recurrency = create_recurrency!(@user, name: "Run")
    @date = Date.current
  end

  test "create completion" do
    assert_difference -> { @recurrency.completions.count }, 1 do
      post recurrency_completion_path(@recurrency),
        params: { date: @date.iso8601, dom_key: "header" },
        as: :turbo_stream
    end

    assert_response :success
    assert @recurrency.completions.exists?(date: @date)
    assert_select "turbo-stream[action=replace][target=#{dom_id(@recurrency, "header_#{@date.iso8601}")}]", count: 1
    assert_select "turbo-stream[action=replace]", count: 1
  end

  test "create is idempotent" do
    @recurrency.completions.create!(date: @date, completed_at: 1.hour.ago)

    assert_no_difference -> { @recurrency.completions.count } do
      post recurrency_completion_path(@recurrency),
        params: { date: @date.iso8601, dom_key: "inline" },
        as: :turbo_stream
    end

    assert_response :success
  end

  test "create rejects unscheduled day" do
    @recurrency.update!(schedule: { "kind" => "custom", "days" => [(@date + 1.day).wday] })

    assert_no_difference -> { @recurrency.completions.count } do
      post recurrency_completion_path(@recurrency),
        params: { date: @date.iso8601, dom_key: "inline" },
        as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  test "destroy completion" do
    @recurrency.completions.create!(date: @date, completed_at: Time.current)

    assert_difference -> { @recurrency.completions.count }, -1 do
      delete recurrency_completion_path(@recurrency),
        params: { date: @date.iso8601, dom_key: "header" },
        as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(@recurrency, "header_#{@date.iso8601}")}]", count: 1
  end
end
