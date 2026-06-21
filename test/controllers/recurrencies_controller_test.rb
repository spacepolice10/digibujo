# frozen_string_literal: true

require "test_helper"

class RecurrenciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @recurrency = create_recurrency!(@user, name: "Run")
  end

  test "index lists recurrencies" do
    get recurrencies_path

    assert_response :success
    assert_match "Run", response.body
  end

  test "create recurrency" do
    assert_difference -> { @user.recurrencies.count }, 1 do
      post recurrencies_path, params: {
        recurrency: { name: "Read", schedule_kind: "weekdays", colour: "cobalt", icon: "books" }
      }
    end

    created = Recurrency.order(:id).last
    assert_redirected_to recurrency_path(created)
    assert_equal "cobalt", created.colour
    assert_equal "books", created.icon
  end

  test "update recurrency" do
    @recurrency.update!(colour: "teal", icon: "muscle")

    patch recurrency_path(@recurrency), params: {
      recurrency: { name: "Morning run", schedule_kind: "daily" }
    }

    assert_redirected_to recurrency_path(@recurrency)
    @recurrency.reload
    assert_equal "Morning run", @recurrency.name
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

    assert_redirected_to recurrencies_path
  end
end
