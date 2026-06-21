# frozen_string_literal: true

require 'test_helper'

class BulletCreatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'creates bullet with default type' do
    result = BulletCreator.new(@user, { body: 'Test body', pops_on: Date.current.iso8601 }).call
    assert result.success?
    assert_equal Bullet::DEFAULT_COMPOSER_TYPE, result.bullet.bulletable_type
    assert_equal 'Test body', result.bullet.body.to_plain_text
  end

  test 'creates bullet with specified type' do
    result = BulletCreator.new(@user, { bulletable_type: 'Note', body: 'A note' }).call
    assert result.success?
    assert_equal 'Note', result.bullet.bulletable_type
  end

  test 'creates bullet with bucket_id' do
    collection = create_collection!(@user, name: 'Test')
    result = BulletCreator.new(@user, { bulletable_type: 'Task', body: 'Collected', bucket_id: collection.bucket.id }).call
    assert result.success?
    assert_equal collection.bucket.id, result.bullet.bucket_id
  end

  test 'tags project from body attachment' do
    project = create_project!(@user, name: 'Tagged')
    body_html = ActionText::Content.new('').append_attachables(project).to_html
    result = BulletCreator.new(@user, { bulletable_type: 'Task', body: body_html }).call
    assert result.success?
    assert_includes result.bullet.projects, project
  end

  test 'fails with validation error' do
    result = BulletCreator.new(@user, { bulletable_type: 'Task', body: '' }).call
    assert_not result.success?
    assert result.bullet.errors[:body].any?
  end

  test 'purges blank rich_body' do
    result = BulletCreator.new(@user, { bulletable_type: 'Task', body: 'Only body', rich_body: '' }).call
    assert result.success?
    assert_not result.bullet.rich_body?
  end

  test 'persists rich_body' do
    result = BulletCreator.new(@user, { bulletable_type: 'Note', body: 'Short', rich_body: '<p>Long detail</p>' }).call
    assert result.success?
    assert result.bullet.rich_body?
    assert_match 'Long detail', result.bullet.rich_body.to_plain_text
  end

  test 'sets note mood and flags' do
    result = BulletCreator.new(@user, {
      bulletable_type: 'Note', body: 'Moody',
      bulletable_attributes: ActionController::Parameters.new(mood: 'inspired', awaits_research: '1', idea: '1')
    }).call
    assert result.success?
    assert_equal 'inspired', result.bullet.bulletable.mood
    assert result.bullet.bulletable.awaits_research
    assert result.bullet.bulletable.idea
  end
end
