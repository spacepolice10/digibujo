# frozen_string_literal: true

require 'test_helper'

class Bullet::MentionsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = create_project!(@user, name: 'alpha')
    @other_project = create_project!(@user, name: 'beta')
    @person = create_person!(@user, name: 'ada')
    @bullet = @user.bullets.create!(bulletable: Note.new(body: 'Note'))
  end

  test 'add_mention! mentions project' do
    @bullet.add_mention!(mention_id: @project.id)

    assert_includes @bullet.reload.mentions, @project
  end

  test 'add_mention! allows multiple mentions' do
    @bullet.add_mention!(mention_id: @project.id)
    @bullet.add_mention!(mention_id: @other_project.id)

    assert_equal 2, @bullet.reload.mentions.count
  end

  test 'remove_mention! drops one mention' do
    @bullet.add_mention!(mention_id: @project.id)
    @bullet.add_mention!(mention_id: @other_project.id)

    @bullet.remove_mention!(mention_id: @project.id)

    assert_not_includes @bullet.reload.mentions, @project
    assert_includes @bullet.mentions, @other_project
  end

  test 'clear_mentions! removes all mentions' do
    @bullet.add_mention!(mention_id: @project.id)

    @bullet.clear_mentions!

    assert_empty @bullet.reload.mentions
  end

  test 'project attachable link renders correct path' do
    content = ActionText::Content.new('Note').append_attachables(@project).to_html
    bullet = @user.bullets.create!(bulletable: Note.new(body: content))

    assert_includes bullet.body.body_before_type_cast.to_s, @project.id.to_s
  end

  test 'note body save syncs mentions from attachments' do
    content = ActionText::Content.new('Ship it').append_attachables(@project).to_html
    @bullet.bulletable.update!(body: content)

    assert_includes @bullet.reload.mentions, @project
    assert_match 'Ship it', @bullet.body.to_plain_text
    assert_includes @bullet.body.body.to_html, 'action-text-attachment'
    assert_includes @bullet.body.body.attachables.grep(Mention), @project
  end

  test 'update clears mentions when attachments are removed from note content' do
    content = ActionText::Content.new('Ship it').append_attachables(@project).to_html
    @bullet.bulletable.update!(body: content)
    assert_includes @bullet.reload.mentions, @project

    @bullet.bulletable.update!(body: 'Ship it without mentions')

    assert_empty @bullet.reload.mentions
  end

  test 'task plain body does not sync mentions' do
    content = ActionText::Content.new('Ship it').append_attachables(@project).to_html
    task = @user.bullets.create!(bulletable: Task.new(body: content))

    assert_empty task.reload.mentions
  end

  test 'bullet_mention rejects cross-user mention' do
    other_project = create_project!(users(:two), name: 'other')
    join = BulletMention.new(bullet: @bullet, mention: other_project)

    assert_not join.valid?
  end

  test 'add_mention! mentions person' do
    @bullet.add_mention!(mention_id: @person.id)

    assert_includes @bullet.reload.mentions, @person
  end
end
