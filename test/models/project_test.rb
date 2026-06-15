# frozen_string_literal: true

require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'requires name' do
    project = @user.projects.build(name: '')
    assert_not project.valid?
  end

  test 'normalizes name' do
    project = create_project!(@user, name: '  Beta  ')
    assert_equal 'beta', project.name
  end

  test 'project names may duplicate per user' do
    create_project!(@user, name: 'alpha')
    duplicate = @user.projects.build(name: 'alpha')
    assert duplicate.valid?
  end
end
