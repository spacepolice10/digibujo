# frozen_string_literal: true

require 'test_helper'
require 'action_text'

class MovePlainBulletableBodiesOffActionTextTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'Task Event Voice store plain body columns and Note keeps ActionText' do
    assert_includes Task.column_names, 'body'
    assert_includes Event.column_names, 'body'
    assert_includes Voice.column_names, 'body'
    assert_not_includes Note.column_names, 'body'

    task = Task.create!(body: 'plain task')
    note = Note.create!(body: '<p>rich note</p>')

    assert_equal 'plain task', task.body
    assert_nil ActionText::RichText.find_by(name: 'body', record_type: 'Task', record_id: task.id)
    assert_match 'rich note', note.body.to_plain_text
    assert ActionText::RichText.exists?(name: 'body', record_type: 'Note', record_id: note.id)
  end

  test 'backfill copies ActionText plain text into Task body then deletes the rich text row' do
    task = Task.create!(body: '')
    ActionText::RichText.create!(record_type: 'Task', record_id: task.id, name: 'body', body: '<p>migrated caption</p>')
    Task.where(id: task.id).update_all(body: '')

    ActionText::RichText.where(name: 'body', record_type: 'Task', record_id: task.id).find_each do |rich_text|
      Task.where(id: rich_text.record_id).update_all(body: rich_text.body.to_plain_text.to_s)
      rich_text.destroy!
    end

    assert_equal 'migrated caption', task.reload.body
    assert_nil ActionText::RichText.find_by(name: 'body', record_type: 'Task', record_id: task.id)
  end
end
