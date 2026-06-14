# frozen_string_literal: true

require "test_helper"

class ProjectableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = create_project!(@user, name: "alpha")
    @other_project = create_project!(@user, name: "beta")
    @bullet = @user.bullets.create!(bulletable: Task.create!, content: "Task")
  end

  test "tag_project! associates project" do
    @bullet.tag_project!(project_id: @project.id)

    assert_includes @bullet.reload.projects, @project
    assert @bullet.triaged_at.present?
  end

  test "tag_project! allows multiple projects" do
    @bullet.tag_project!(project_id: @project.id)
    @bullet.tag_project!(project_id: @other_project.id)

    assert_equal 2, @bullet.reload.projects.count
  end

  test "untag_project! removes one project tag" do
    @bullet.tag_project!(project_id: @project.id)
    @bullet.tag_project!(project_id: @other_project.id)

    @bullet.untag_project!(project_id: @project.id)

    assert_not_includes @bullet.reload.projects, @project
    assert_includes @bullet.projects, @other_project
  end

  test "untag_all_projects! clears tags" do
    @bullet.tag_project!(project_id: @project.id)

    @bullet.untag_all_projects!

    assert_empty @bullet.reload.projects
  end

  test "project attachable link keeps data-turbo-frame in rendered content" do
    content = ActionText::Content.new("Task").append_attachables(@project).to_html
    bullet = @user.bullets.create!(bulletable: Task.create!, content: content)

    assert_includes bullet.content.to_s, 'data-turbo-frame="_top"'
    assert_includes bullet.content.to_s, "/projects/#{@project.id}"
  end

  test "apply_project_tags_from_content! extracts project attachments" do
    content = ActionText::Content.new("Ship it").append_attachables(@project).to_html
    @bullet.update!(content: content)

    assert_includes @bullet.reload.projects, @project
    assert_match "Ship it", @bullet.content.to_plain_text
    assert_includes @bullet.content.body.to_html, "action-text-attachment"
    assert_includes @bullet.content.body.attachables.grep(Project), @project
  end

  test "bullet_project rejects cross-user association" do
    other_project = create_project!(users(:two), name: "other")
    join = BulletProject.new(bullet: @bullet, project: other_project)

    assert_not join.valid?
  end

  test "editor_content avoids rendered layout markup" do
    content = @bullet.editor_content(default_projects: [ @project ])

    html = content.fragment.to_html
    assert_includes html, "action-text-attachment"
    assert_not_includes html, "BEGIN app/views/layouts"
  end

  test "editor_content hydrates project attachments for lexxy" do
    content = @bullet.editor_content(default_projects: [ @project ])
    hydrated = ApplicationController.helpers.send(:render_custom_attachments_in, content)

    assert_includes hydrated, 'content="'
    assert_includes hydrated, @project.name
    assert_includes hydrated, "pill"
    assert_not_includes hydrated, "attachment--unknown"
  end
end
