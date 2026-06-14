# frozen_string_literal: true

require "test_helper"

class Bullets::CollectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create redirects to daylog and tags project" do
    project = create_project!(@user, name: "Ideas")
    card = @user.bullets.create!(bulletable: Task.create!, content: "Move me")

    post collect_path, params: { bullet_ids: card.id.to_s, project_id: project.id }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_includes card.reload.projects, project
    assert_nil card.bucket_id
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
    assert_match "Tag project", response.body
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

  test "create tags bullet with selected project" do
    card = @user.bullets.create!(bulletable: Note.create!, content: "Solo")
    project = create_project!(@user, name: "scratchpad")

    post collect_path, params: { bullet_ids: card.id.to_s, project_id: project.id }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_includes card.reload.projects, project
  end

  test "create tags multiple bullets with one project" do
    project = create_project!(@user, name: "Batch")
    first = @user.bullets.create!(bulletable: Task.create!, content: "One")
    second = @user.bullets.create!(bulletable: Note.create!, content: "Two")

    post collect_path,
         params: { bullet_ids: "#{first.id},#{second.id}", project_id: project.id }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_includes first.reload.projects, project
    assert_includes second.reload.projects, project
  end

  test "create turbo stream keeps bullet on monthly bucket spread when tagging project" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")
    project = create_project!(@user, name: "Ideas")
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Leave spread",
      bucket_id: monthly_bucket.bucket.id
    )

    post collect_path,
         params: { bullet_ids: card.id.to_s, project_id: project.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    card.reload
    assert_includes card.projects, project
    assert_equal monthly_bucket.bucket.id, card.bucket_id
    assert_match %(turbo-stream action="replace" target="bullet_#{card.id}"), response.body
    assert_no_match "bullet-compact", response.body
  end

  test "destroy untags multiple bullets" do
    project = create_project!(@user, name: "Clear")
    first = @user.bullets.create!(bulletable: Task.create!, content: "A")
    second = @user.bullets.create!(bulletable: Note.create!, content: "B")
    first.tag_project!(project_id: project.id)
    second.tag_project!(project_id: project.id)

    delete collect_path, params: { bullet_ids: "#{first.id},#{second.id}" }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_empty first.reload.projects
    assert_empty second.reload.projects
  end
end
