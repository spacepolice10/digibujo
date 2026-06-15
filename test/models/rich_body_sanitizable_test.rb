# frozen_string_literal: true

require 'test_helper'

class RichBodySanitizableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = create_project!(@user, name: 'alpha')
    @bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task')
  end

  test 'sanitize_rich_body_tag_attachables! removes project pills from rich_body' do
    rich_body = ActionText::Content.new('Notes').append_attachables(@project).to_html
    @bullet.update!(rich_body: rich_body)

    @bullet.sanitize_rich_body_tag_attachables!

    assert_empty @bullet.reload.rich_body.body.attachables.grep(Project)
    assert_match 'Notes', @bullet.rich_body.to_plain_text
  end
end
