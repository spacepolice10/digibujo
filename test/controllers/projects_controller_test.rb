# frozen_string_literal: true

require 'test_helper'

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index lists projects' do
    create_project!(@user, name: 'alpha')
    create_project!(@user, name: 'beta')

    get projects_path

    assert_response :success
    assert_match 'alpha', response.body
    assert_match 'beta', response.body
  end

  test 'show renders project bullets' do
    project = create_project!(@user, name: 'alpha')
    create_bullet!(@user, bulletable: Task.new(body: 'Tagged task')).tap do |b|
      b.bullet_projects.create!(project: project)
    end

    get project_path(project)

    assert_response :success
    assert_match 'Tagged task', response.body
  end

  test 'create project' do
    assert_difference -> { Project.count }, 1 do
      post projects_path, params: { project: { name: 'Nova', colour: 'gold' } }
    end

    assert_redirected_to home_path
    assert_equal 'nova', Project.order(:id).last.name
  end
end
