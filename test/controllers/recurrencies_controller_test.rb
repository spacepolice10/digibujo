# frozen_string_literal: true

require "test_helper"

class RecurrenciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @recurrency = create_recurrency!(@user, name: "Run")
  end

  test "show renders lifetime statistics and 30-day heatmap" do
    @recurrency.completions.create!(date: Date.current, completed_at: Time.current)

    get recurrency_path(@recurrency)

    assert_response :success
    assert_select ".recurrency--statistics dt", text: "Current streak"
    assert_select ".recurrency--statistics dt", text: "Best streak"
    assert_select ".recurrency--statistics dt", text: "Total days"
    assert_select ".recurrency--statistics dt", text: "This month", count: 0
    assert_select ".recurrency--heatmap-day", count: 30
    assert_select ".recurrency--month-nav", count: 0
    assert_select ".recurrency--grid", count: 0
  end

  test "create recurrency" do
    assert_difference -> { @user.recurrencies.count }, 1 do
      post recurrencies_path, params: {
        recurrency: { name: "Read", schedule_days: %w[1 2 3 4 5], colour: "cobalt", icon: "books" }
      }
    end

    created = Recurrency.order(:id).last
    assert_redirected_to home_path
    assert_equal [1, 2, 3, 4, 5], created.schedule_days
    assert_equal "cobalt", created.colour
    assert_equal "books", created.icon
  end

  test "update recurrency" do
    @recurrency.update!(colour: "teal", icon: "muscle")

    patch recurrency_path(@recurrency), params: {
      recurrency: { name: "Morning run", schedule_days: %w[0 6] }
    }

    assert_redirected_to recurrency_path(@recurrency)
    @recurrency.reload
    assert_equal "Morning run", @recurrency.name
    assert_equal [0, 6], @recurrency.schedule_days
    assert_equal "teal", @recurrency.colour
    assert_equal "muscle", @recurrency.icon
  end

  test "destroy blocked when completions exist" do
    @recurrency.completions.create!(date: Date.current, completed_at: Time.current)

    assert_no_difference -> { Recurrency.count } do
      delete recurrency_path(@recurrency)
    end

    assert_redirected_to recurrency_path(@recurrency)
    assert_match "Cannot delete", flash[:alert]
  end

  test "destroy succeeds without completions" do
    assert_difference -> { Recurrency.count }, -1 do
      delete recurrency_path(@recurrency)
    end

    assert_redirected_to home_path
  end
end
