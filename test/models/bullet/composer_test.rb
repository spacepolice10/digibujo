# frozen_string_literal: true

require 'test_helper'

class Bullet::ComposerTest < ActiveSupport::TestCase
  test 'type options include all bulletable types in order' do
    options = Bullet::Composer.type_options
    values = options.map { |o| o[:type] }

    assert_equal %w[Task Note Event], values
  end

  test 'type options include expected metadata for each type' do
    note_option = Bullet::Composer.type_options.find { |o| o[:type] == 'Note' }

    assert_equal 'Note', note_option[:name]
    assert_equal 'Reference or log entry', note_option[:hint]
    assert_equal 'line-dashed', note_option[:icon]
    assert_equal 'note', note_option[:modifier]
    assert_equal 'bullet--note-marker', note_option[:marker_styles]
  end

  test 'action options include attachment for Note only' do
    note_options = Note.composer_action_options
    task_options = Task.composer_action_options

    assert_includes note_options.map { |o| o[:value] }, 'attachment'
    assert_empty task_options
  end

  test 'type options include editor metadata' do
    note_option = Bullet::Composer.type_options.find { |o| o[:type] == 'Note' }
    task_option = Bullet::Composer.type_options.find { |o| o[:type] == 'Task' }

    assert_equal 'note', note_option[:actiontext_preset]
    assert note_option[:accepts_editor_attachments]
    assert_not note_option[:submit_on_enter]
    assert note_option[:submit_on_command_return]
    assert_not note_option[:close_composer_on_submit]

    assert_equal 'inline', task_option[:actiontext_preset]
    assert_not task_option[:accepts_editor_attachments]
    assert task_option[:submit_on_enter]
    assert_not task_option[:submit_on_command_return]
    assert_not task_option[:close_composer_on_submit]
  end

  test 'form partial path is set only for types with composer fields' do
    assert_equal 'notes/composer_fields', Bullet::Composer.form_partial_path('Note')
    assert_nil Bullet::Composer.form_partial_path('Task')
    assert_nil Bullet::Composer.form_partial_path('Event')
  end
end
