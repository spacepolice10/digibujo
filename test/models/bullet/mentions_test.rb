# frozen_string_literal: true

require 'test_helper'

class Bullet::MentionsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = create_project!(@user, name: 'alpha')
    @other_project = create_project!(@user, name: 'beta')
    @person = @user.people.create!(name: 'ada')
    @bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task')
  end

  test 'projects.add! mentions project' do
    @bullet.mentions.projects.add!(project_id: @project.id)

    assert_includes @bullet.reload.projects, @project
  end

  test 'projects.add! allows multiple projects' do
    @bullet.mentions.projects.add!(project_id: @project.id)
    @bullet.mentions.projects.add!(project_id: @other_project.id)

    assert_equal 2, @bullet.reload.projects.count
  end

  test 'projects.remove! drops one project mention' do
    @bullet.mentions.projects.add!(project_id: @project.id)
    @bullet.mentions.projects.add!(project_id: @other_project.id)

    @bullet.mentions.projects.remove!(project_id: @project.id)

    assert_not_includes @bullet.reload.projects, @project
    assert_includes @bullet.projects, @other_project
  end

  test 'projects.clear! removes all project mentions' do
    @bullet.mentions.projects.add!(project_id: @project.id)

    @bullet.mentions.projects.clear!

    assert_empty @bullet.reload.projects
  end

  test 'project attachable link renders correct path' do
    content = ActionText::Content.new('Task').append_attachables(@project).to_html
    bullet = @user.bullets.create!(bulletable: Task.create!, body: content)

    assert_includes bullet.body.to_s, "/projects/#{@project.id}"
  end

  test 'body save syncs project mentions from attachments' do
    content = ActionText::Content.new('Ship it').append_attachables(@project).to_html
    @bullet.update!(body: content)

    assert_includes @bullet.reload.projects, @project
    assert_match 'Ship it', @bullet.body.to_plain_text
    assert_includes @bullet.body.body.to_html, 'action-text-attachment'
    assert_includes @bullet.body.body.attachables.grep(Project), @project
  end

  test 'update clears project mentions when attachments are removed from content' do
    content = ActionText::Content.new('Ship it').append_attachables(@project).to_html
    @bullet.update!(body: content)
    assert_includes @bullet.reload.projects, @project

    @bullet.update!(body: 'Ship it without mentions')

    assert_empty @bullet.reload.projects
  end

  test 'bullet_project rejects cross-user mention' do
    other_project = create_project!(users(:two), name: 'other')
    join = BulletProject.new(bullet: @bullet, project: other_project)

    assert_not join.valid?
  end

  test 'bullet_person rejects cross-user mention' do
    other_person = users(:two).people.create!(name: 'other')
    join = BulletPerson.new(bullet: @bullet, person: other_person)

    assert_not join.valid?
  end

  test 'editor_content avoids rendered layout markup' do
    @bullet.mentions.projects.add!(project_id: @project.id)
    content = @bullet.editor_content

    html = content.fragment.to_html
    assert_includes html, 'action-text-attachment'
    assert_not_includes html, 'BEGIN app/views/layouts'
  end

  test 'editor_content_for_form returns raw HTML with project attachment node' do
    @bullet.mentions.projects.add!(project_id: @project.id)
    html = @bullet.editor_content_for_form

    assert_includes html, 'action-text-attachment'
    assert_not_includes html, 'attachment--unknown'
  end

  test 'people.add! mentions person' do
    @bullet.mentions.people.add!(person_id: @person.id)

    assert_includes @bullet.reload.people, @person
  end
end
