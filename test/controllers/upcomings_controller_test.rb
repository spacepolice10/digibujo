require "test_helper"

class UpcomingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show renders task-circle completion controls for completable cards" do
    task = Task.create!
    event = Event.create!

    @user.cards.create!(cardable: task, content: "Finish writeup", date: Date.today + 1.day)
    @user.cards.create!(cardable: event, content: "Attend meetup", date: Date.today + 1.day)

    get upcoming_path

    assert_response :success
    assert_select ".calendar-card .calendar-card-type-toggle--task", count: 1
    assert_select ".calendar-card .completion-toggle", count: 0
  end
end
