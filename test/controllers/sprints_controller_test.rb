# frozen_string_literal: true

require "test_helper"

class SprintsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "routes are not found when sprints are disabled" do
    sprint = create_sprint!(@user, name: "Old sprint", starts_on: Date.current, ends_on: Date.current + 6.days)

    get sprint_path(sprint)
    assert_response :not_found

    get new_sprint_path
    assert_response :not_found

    post sprints_path, params: {
      sprint: {
        name: "Launch",
        starts_on: Date.current.iso8601,
        ends_on: (Date.current + 13.days).iso8601
      }
    }
    assert_response :not_found
  end

  test "create records bucket created activity" do
    with_sprints_enabled do
      assert_difference -> { Activity.count }, 1 do
        post sprints_path, params: {
          sprint: {
            name: "Launch",
            colour: "teal",
            icon: "folder",
            description: "Ship v1",
            starts_on: Date.current.iso8601,
            ends_on: (Date.current + 13.days).iso8601
          }
        }
      end

      activity = Activity.order(:created_at).last
      assert_equal "created", activity.action
      assert_equal "Bucket", activity.subject_type
      assert_equal "Sprint", activity.metadata["bucketable_type"]
      assert_equal "Ship v1", Sprint.last.bucket.description
      assert_redirected_to sprint_path(Sprint.last)
    end
  end

  test "create with bullet_ids collects bullets and returns turbo stream" do
    with_sprints_enabled do
      first = @user.bullets.create!(bulletable: Task.create!, body: "One")
      second = @user.bullets.create!(bulletable: Note.create!, body: "Two")

      assert_difference -> { Sprint.count }, 1 do
        post sprints_path,
             params: {
               sprint: {
                 name: "Fresh sprint",
                 colour: "teal",
                 icon: "folder",
                 starts_on: Date.current.iso8601,
                 ends_on: (Date.current + 6.days).iso8601
               },
               bullet_ids: "#{first.id},#{second.id}"
             },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      sprint = Sprint.last
      assert_equal sprint.bucket.id, first.reload.bucket_id
      assert_equal sprint.bucket.id, second.reload.bucket_id
      assert first.migrated?
      assert second.migrated?
      assert_match %(turbo-stream action="remove" targets="#bullet_#{first.id}"), response.body
      assert_match %(turbo-stream action="remove" targets="#bullet_#{second.id}"), response.body
    end
  end

  test "destroy archives sprint and hides it from active lists" do
    with_sprints_enabled do
      sprint = create_sprint!(@user, name: "Old sprint", starts_on: Date.current, ends_on: Date.current + 6.days)
      card = @user.bullets.create!(bulletable: Task.create!, body: "Stay", bucket_id: sprint.bucket.id)

      assert_no_difference -> { Sprint.count } do
        delete sprint_path(sprint)
      end

      assert_redirected_to home_path
      assert sprint.bucket.reload.archived?
      assert_equal sprint.bucket.id, card.reload.bucket_id
      assert_empty Sprint.joins(:bucket).merge(Bucket.where(user_id: @user.id).active).where(sprints: { id: sprint.id })
    end
  end

  test "show displays sprint progress" do
    with_sprints_enabled do
      sprint = create_sprint!(@user, name: "Active", starts_on: Date.current, ends_on: Date.current + 6.days)
      @user.bullets.create!(bulletable: Task.create!(completed: true), body: "Done", bucket_id: sprint.bucket.id)
      @user.bullets.create!(bulletable: Task.create!, body: "Todo", bucket_id: sprint.bucket.id)

      get sprint_path(sprint)

      assert_response :success
      assert_match "1/2 tasks", response.body
      assert_match "6d left", response.body
    end
  end
end
