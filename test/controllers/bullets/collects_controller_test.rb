# frozen_string_literal: true

require "test_helper"

class Bullets::CollectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create redirects to daylog and assigns project bucket" do
    project = create_project!(@user, name: "Ideas")
    card = @user.bullets.create!(bulletable: Task.create!, content: "Move me")

    post collect_path, params: { bullet_ids: card.id.to_s, project_id: project.id }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal project.bucket, card.reload.bucket
  end

  test "new renders project picker for selected bullets" do
    project = create_project!(@user, name: "Ideas")
    card = @user.bullets.create!(bulletable: Task.create!, content: "Move me")

    get new_collect_path, params: { bullet_ids: card.id.to_s }

    assert_response :success
    assert_select "turbo-frame#collects_picker_frame"
    assert_select "form[action=?][data-turbo-frame=?]", new_collect_path, "collects_picker_frame"
    assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]'
    assert_match project.name, response.body
    assert_match "Collect to project", response.body
  end

  test "new renders picker content inside turbo frame request" do
    project = create_project!(@user, name: "Ideas")
    card = @user.bullets.create!(bulletable: Task.create!, content: "Move me")

    get new_collect_path,
        params: { bullet_ids: card.id.to_s },
        headers: { "Turbo-Frame" => "collects_picker_frame" }

    assert_response :success
    assert_select "turbo-frame#collects_picker_frame .bulk-menu--pops-header"
    assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]'
    assert_match project.name, response.body
  end

  test "new filters projects by search query" do
    create_project!(@user, name: "alpha")
    create_project!(@user, name: "beta")
    card = @user.bullets.create!(bulletable: Task.create!, content: "Move me")

    get new_collect_path, params: { bullet_ids: card.id.to_s, q: "alp" }

    assert_response :success
    assert_match "alpha", response.body
    assert_no_match "beta", response.body
  end

  test "create assigns project bucket for new project name" do
    card = @user.bullets.create!(bulletable: Note.create!, content: "Solo")
    project = create_project!(@user, name: "scratchpad")

    post collect_path, params: { bullet_ids: card.id.to_s, project_id: project.id }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal "scratchpad", card.reload.bucket.name
  end

  test "create collects multiple bullets into one bucket" do
    project = create_project!(@user, name: "Batch")
    first = @user.bullets.create!(bulletable: Task.create!, content: "One")
    second = @user.bullets.create!(bulletable: Note.create!, content: "Two")

    post collect_path,
         params: { bullet_ids: "#{first.id},#{second.id}", project_id: project.id }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal project.bucket, first.reload.bucket
    assert_equal project.bucket, second.reload.bucket
  end

  test "destroy uncollects multiple bullets" do
    project = create_project!(@user, name: "Clear")
    first = @user.bullets.create!(bulletable: Task.create!, content: "A", bucket: project.bucket)
    second = @user.bullets.create!(bulletable: Note.create!, content: "B", bucket: project.bucket)

    delete collect_path, params: { bullet_ids: "#{first.id},#{second.id}" }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_nil first.reload.bucket_id
    assert_nil second.reload.bucket_id
  end
end
