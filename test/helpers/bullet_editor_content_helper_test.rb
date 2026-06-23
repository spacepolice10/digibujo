# frozen_string_literal: true

require 'test_helper'

class BulletEditorContentHelperTest < ActionView::TestCase
  include BulletEditorContentHelper

  setup do
    @user = users(:one)
    @project = create_project!(@user, name: 'alpha')
    @person = @user.people.create!(name: 'ada')
  end

  test 'hydrate_editor_content returns blank html unchanged' do
    assert_equal '', hydrate_editor_content('')
    assert_nil hydrate_editor_content(nil)
  end

  test 'hydrate_editor_content renders project pill into attachment node' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task')
    bullet.tag_project!(project_id: @project.id)
    raw_html = bullet.editor_content_for_form

    hydrated = hydrate_editor_content(raw_html)

    assert_includes hydrated, 'content="'
    assert_includes hydrated, @project.name
    assert_includes hydrated, 'pill'
    assert_not_includes hydrated, 'attachment--unknown'
  end

  test 'hydrate_editor_content renders person pill into attachment node' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task')
    bullet.tag_person!(person_id: @person.id)
    raw_html = bullet.editor_content_for_form

    hydrated = hydrate_editor_content(raw_html)

    assert_includes hydrated, 'content="'
    assert_includes hydrated, @person.name
    assert_includes hydrated, 'pill'
  end
end
