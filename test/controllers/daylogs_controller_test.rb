# frozen_string_literal: true

require "test_helper"

class DaylogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "daylog without date shows today" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Today card")

    get daylog_path

    assert_response :success
    assert_match card.content.to_plain_text, response.body
  end

  test "daylog with year month day shows that day" do
    selected_date = Date.current - 2.days
    travel_to selected_date.in_time_zone.change(hour: 10) do
      @user.bullets.create!(bulletable: Task.create!, content: "That day")
    end
    @user.bullets.create!(bulletable: Task.create!, content: "Today noise")

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_match "That day", response.body
    assert_no_match "Today noise", response.body
  end

  test "invalid calendar date returns not found" do
    get daylog_path(date: "#{Date.current.year}-02-30")

    assert_response :not_found
  end

  test "daylog renders date navigation links" do
    selected_date = Date.current - 2.days

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_select "a[href='#{daylog_path(date: (selected_date - 1.day).iso8601)}']"
    assert_select "a[href='#{daylog_path(date: (selected_date + 1.day).iso8601)}']"
  end

  test "daylog scopes bulk menu controls to the bullets list" do
    @user.bullets.create!(bulletable: Task.create!, content: "Selectable card", pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_select "[data-controller~=?]", "bullets-bulk", 0
    assert_select "[data-controller~=?]", "bulk-menu" do
      assert_select "#bullets[data-bulk-menu-target=?]", "list"
      assert_select ".bulk-menu[data-bulk-menu-target=?]", "menu"
      assert_select "input[type=checkbox][data-bulk-menu-target=?]", "checkbox"
    end
  end

  test "daylog renders simple editor with selected day as submitted attribute" do
    selected_date = Date.current - 2.days

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_select "turbo-frame#new_bullet_form form.bullet-form[data-controller~=?]", "editor"
    assert_select ".bullet-form-type-picker[data-editor-target=?]", "typePicker"
    assert_select ".bullet-form-type-marker[data-editor-target=?]", "typeMarker"
    assert_select "select.bullet-form-type-select[name=?][required][data-editor-target=?]", "bullet[bulletable_type]", "typeSelect" do
      assert_select "option", text: "Task"
      assert_select "option[selected]", text: "Note"
      assert_select "option", text: "Event"
    end
    assert_select "input[type=hidden][name=?][value=?]", "bullet[pops_on]", selected_date.iso8601
    assert_select ".bullet-form-fields", 0
  end

  test "root shows today daylog" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Root today")

    get root_path

    assert_response :success
    assert_match card.content.to_plain_text, response.body
  end
end
