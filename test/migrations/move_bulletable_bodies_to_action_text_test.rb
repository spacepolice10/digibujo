# frozen_string_literal: true

require 'test_helper'
require 'action_text'
require Rails.root.join('db/migrate/20260726120000_move_bulletable_bodies_to_action_text')

class MoveBulletableBodiesToActionTextTest < ActiveSupport::TestCase
  PLAIN_TYPES = %w[Task Event Voice].freeze

  setup do
    add_plain_body_columns!
  end

  teardown do
    reset_column_information!
  end

  test 'copies plain bodies into Action Text and drops the columns' do
    task = Task.create!
    event = Event.create!
    write_plain_body(task, "Buy milk\nand bread")
    write_plain_body(event, 'Dentist')

    run_migration

    assert_not_includes Task.column_names, 'body'
    assert_not_includes Event.column_names, 'body'
    assert_not_includes Voice.column_names, 'body'

    assert_equal "Buy milk\n\nand bread", task.reload.body_as_text.strip
    assert_equal 'Dentist', event.reload.body_as_text.strip
  end

  test 'escapes markup from plain bodies' do
    task = Task.create!
    write_plain_body(task, '<script>alert(1)</script>')

    run_migration

    assert_equal '<script>alert(1)</script>', task.reload.body_as_text.strip
  end

  test 'skips blank bodies' do
    task = Task.create!
    write_plain_body(task, '   ')

    run_migration

    assert_equal 0, ActionText::RichText.where(name: 'body', record_type: 'Task', record_id: task.id).count
  end

  test 'keeps rich text that already exists' do
    task = Task.create!(body: '<p>already rich</p>')
    write_plain_body(task, 'stale plain copy')

    run_migration

    assert_equal 1, ActionText::RichText.where(name: 'body', record_type: 'Task', record_id: task.id).count
    assert_equal 'already rich', task.reload.body_as_text.strip
  end

  private

  def run_migration
    ActiveRecord::Migration.suppress_messages { MoveBulletableBodiesToActionText.new.up }
    reset_column_information!
  end

  def add_plain_body_columns!
    ActiveRecord::Migration.suppress_messages do
      PLAIN_TYPES.each do |type|
        connection.add_column type.tableize, :body, :text, null: false, default: ''
      end
    end
    reset_column_information!
  end

  def write_plain_body(record, text)
    connection.execute(
      "UPDATE #{record.class.table_name} SET body = #{connection.quote(text)} WHERE id = #{record.id}"
    )
  end

  def reset_column_information!
    PLAIN_TYPES.each { |type| type.constantize.reset_column_information }
  end

  def connection
    ActiveRecord::Base.connection
  end
end
