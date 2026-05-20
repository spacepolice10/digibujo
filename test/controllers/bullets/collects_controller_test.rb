# frozen_string_literal: true

require "test_helper"

class Bullets::CollectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create redirects to bullets and assigns project bucket" do
    project = create_project!(@user, name: "Ideas")
    card = @user.bullets.create!(bulletable: Task.create!, content: "Move me")

    post bullet_collect_path(card), params: { bucket_id: project.bucket.id }

    assert_redirected_to bullets_path
    assert_equal project.bucket, card.reload.bucket
  end

  test "create assigns project bucket for new project name" do
    card = @user.bullets.create!(bulletable: Note.create!, content: "Solo")

    post "/projects",
         params: { project: { name: "scratchpad" } }.to_json,
         headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :created
    bucket_id = JSON.parse(response.body).dig("project", "bucket_id")

    post bullet_collect_path(card), params: { bucket_id: bucket_id }

    assert_redirected_to bullets_path
    assert_equal "scratchpad", card.reload.projects.first.name
  end
end
