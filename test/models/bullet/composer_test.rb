# frozen_string_literal: true

require 'test_helper'

class Bullet::ComposerTest < ActiveSupport::TestCase
  test 'default type is Note' do
    assert_equal 'Note', Bullet::Composer.default_type
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

  test 'action options include attachment and expand' do
    options = Bullet::Composer.action_options
    values = options.map { |o| o[:value] }

    assert_includes values, 'attachment'
    assert_includes values, 'expand'
  end

  test 'config_for returns config for a type' do
    config = Bullet::Composer.config_for('Note')

    assert_equal 'Note', config[:label]
    assert_equal 'bullets/composer/note', config[:form_partial]
  end

  test 'form partial path is present for Note' do
    assert_equal 'bullets/composer/note', Bullet::Composer.form_partial_path('Note')
  end

  test 'form partial path is nil for types without custom fields' do
    assert_nil Bullet::Composer.form_partial_path('Task')
    assert_nil Bullet::Composer.form_partial_path('Event')
    assert_nil Bullet::Composer.form_partial_path('Title')
  end

  test 'form_fields? is true for types with custom partials' do
    assert Bullet::Composer.form_fields?('Note')
  end

  test 'form_fields? is false for types without custom partials' do
    assert_not Bullet::Composer.form_fields?('Task')
    assert_not Bullet::Composer.form_fields?('Event')
    assert_not Bullet::Composer.form_fields?('Title')
  end
end
