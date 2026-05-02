# frozen_string_literal: true

require "test_helper"

class TriageControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "triage shows selected date entries" do
    selected_date = Date.current - 1.day
    selected_day_card = nil

    travel_to selected_date.in_time_zone.change(hour: 10) do
      selected_day_card = @user.bullets.create!(bulletable: Task.create!, content: "Selected triage day card")
    end

    @user.bullets.create!(bulletable: Task.create!, content: "Current triage day card")

    get triage_path(date: selected_date.iso8601)

    assert_response :success
    assert_match selected_day_card.content.to_plain_text, response.body
    assert_no_match "Current triage day card", response.body
  end

  test "triage falls back to current day for invalid date param" do
    selected_date = Date.current - 1.day

    travel_to selected_date.in_time_zone.change(hour: 10) do
      @user.bullets.create!(bulletable: Task.create!, content: "Old triage day card")
    end

    current_day_card = @user.bullets.create!(bulletable: Task.create!, content: "Current triage day card")

    get triage_path(date: "invalid-date")

    assert_response :success
    assert_match current_day_card.content.to_plain_text, response.body
    assert_no_match "Old triage day card", response.body
  end

  test "triage renders date navigation links" do
    selected_date = Date.current - 2.days

    get triage_path(date: selected_date.iso8601)

    assert_response :success
    assert_select "a[href='#{triage_path(date: (selected_date - 1.day).iso8601)}']"
    assert_select "a[href='#{triage_path(date: (selected_date + 1.day).iso8601)}']"
  end

  test "triage actions use selected date to find bullets" do
    selected_date = Date.current - 1.day
    selected_day_card = nil

    travel_to selected_date.in_time_zone.change(hour: 10) do
      selected_day_card = @user.bullets.create!(bulletable: Task.create!, content: "Archive me")
    end

    post triage_bullet_archive_path(bullet_id: selected_day_card.id, date: selected_date.iso8601)

    assert_redirected_to triage_path(date: selected_date.iso8601)
    assert selected_day_card.reload.archived?
  end
end
