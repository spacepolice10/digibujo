# frozen_string_literal: true

require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "timeline bullets are not draggable" do
    @user.bullets.create!(bulletable: Task.create!, content: "Copy me")
    get bullets_path
    assert_select ".card[draggable='true']", count: 0
    assert_select ".card[data-controller~='card-drag']", count: 0
    assert_select ".card[data-card-drag-id-value]", count: 0
    assert_select ".card-body[data-controller~='card-link']"
  end

  test "create links an existing context card only" do
    context_bullet = @user.bullets.create!(bulletable: Note.create!, content: "Customer notes")

    assert_difference("Bullet.count", 1) do
      post bullets_path, params: {
        card: {
          bulletable_type: "task",
          content: "Task with context",
          context_bullet_id: context_bullet.id
        }
      }
    end

    created_card = @user.bullets.order(:created_at).last
    assert_equal context_bullet.id, created_card.context_bullet_id
  end

  test "bullets view hides archived bullets" do
    visible_card = @user.bullets.create!(bulletable: Task.create!, content: "Visible today")
    hidden_card = @user.bullets.create!(bulletable: Task.create!, content: "Hidden today", archived: true)

    get bullets_path

    assert_response :success
    assert_match visible_card.content.to_plain_text, response.body
    assert_no_match hidden_card.content.to_plain_text, response.body
  end

  test "bullets index shows selected date entries" do
    selected_date = Date.current - 1.day
    previous_day_card = nil

    travel_to selected_date.in_time_zone.change(hour: 10) do
      previous_day_card = @user.bullets.create!(bulletable: Task.create!, content: "Yesterday card")
    end

    @user.bullets.create!(bulletable: Task.create!, content: "Today card")

    get bullets_path(date: selected_date.iso8601)

    assert_response :success
    assert_match previous_day_card.content.to_plain_text, response.body
    assert_no_match "Today card", response.body
  end

  test "bullets index falls back to current day on invalid date param" do
    previous_day = Date.current - 1.day

    travel_to previous_day.in_time_zone.change(hour: 10) do
      @user.bullets.create!(bulletable: Task.create!, content: "Previous day card")
    end

    current_day_card = @user.bullets.create!(bulletable: Task.create!, content: "Current day card")

    get bullets_path(date: "invalid-date")

    assert_response :success
    assert_match current_day_card.content.to_plain_text, response.body
    assert_no_match "Previous day card", response.body
  end

  test "bullets index renders date navigation links for bullets route" do
    selected_date = Date.current - 2.days

    get bullets_path(date: selected_date.iso8601)

    assert_response :success
    assert_select "a[href='#{bullets_path(date: (selected_date - 1.day).iso8601)}']"
    assert_select "a[href='#{bullets_path(date: (selected_date + 1.day).iso8601)}']"
    assert_select "a[href='#{triage_path(date: selected_date.iso8601)}']"
  end

  test "bullets pagination keeps selected date on bullets route" do
    selected_date = Date.current - 1.day

    travel_to selected_date.in_time_zone.change(hour: 10) do
      6.times { |i| @user.bullets.create!(bulletable: Task.create!, content: "Page card #{i}") }
    end

    get bullets_path(date: selected_date.iso8601)

    assert_response :success
    assert_select "a.pagination-trigger[href*='date=#{selected_date.iso8601}']"
  end

end
