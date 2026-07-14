# frozen_string_literal: true

require 'test_helper'

class MentionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'requires name' do
    mention = @user.mentions.project.build(name: '')
    assert_not mention.valid?
  end

  test 'normalizes name' do
    mention = create_project!(@user, name: '  Beta  ')
    assert_equal 'beta', mention.name
  end

  test 'project names are unique per user' do
    create_project!(@user, name: 'alpha')
    duplicate = @user.mentions.project.build(name: 'alpha')
    assert_not duplicate.valid?
  end

  test 'same name allowed across kinds' do
    create_project!(@user, name: 'alpha')
    person = @user.mentions.person.build(name: 'alpha')
    assert person.valid?
  end
end
