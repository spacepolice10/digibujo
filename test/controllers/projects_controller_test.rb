# frozen_string_literal: true

require 'test_helper'

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index renders search form targeting project results' do
    get projects_path

    assert_response :success
    assert_select 'form.search-form[data-turbo-frame=?]', 'projects'
    assert_select 'turbo-frame#projects'
  end

  test 'index filters projects by search query' do
    create_project!(@user, name: 'alpha')
    create_project!(@user, name: 'beta')

    get projects_path, params: { q: 'alp' }

    assert_response :success
    assert_match 'alpha', response.body
    assert_no_match 'beta', response.body
  end

  test 'show renders composer with add bullet link' do
    project = create_project!(@user, name: 'alpha')

    get project_path(project)

    assert_response :success
    assert_select 'turbo-frame#bullet_composer' do
      assert_select 'a[href=?]',
                    new_bullet_path(render_context: 'project', default_project_id: project.id)
    end
    assert_match(/Add bullet/, response.body)
  end
end
