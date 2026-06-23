# frozen_string_literal: true

require 'test_helper'

class Bullet::ComposerTest < ActiveSupport::TestCase
  test 'default type is Task' do
    assert_equal 'Task', Bullet::Composer.default_type
  end

  test 'type options include all bulletable types in order' do
    options = Bullet::Composer.type_options
    values = options.map { |o| o[:value] }

    assert_equal %w[Task Note Event Title], values
  end

  test 'type options include expected metadata for each type' do
    note_option = Bullet::Composer.type_options.find { |o| o[:value] == 'Note' }

    assert_equal 'Note', note_option[:label]
    assert_equal 'Reference or log entry', note_option[:hint]
    assert_equal 'line-dashed', note_option[:icon]
    assert_equal 'note', note_option[:modifier]
    assert_equal 'bullet--note-marker', note_option[:marker_styles]
  end

  test 'action options include attachment' do
    options = Bullet::Composer.action_options
    values = options.map { |o| o[:value] }

    assert_includes values, 'attachment'
  end

  test 'form partial path is present for Note' do
    assert_equal 'bullets/composer/note', Bullet::Composer.form_partial_path('Note')
  end

  test 'form partial path is nil for types without custom fields' do
    assert_nil Bullet::Composer.form_partial_path('Task')
    assert_nil Bullet::Composer.form_partial_path('Event')
    assert_nil Bullet::Composer.form_partial_path('Title')
  end
end
