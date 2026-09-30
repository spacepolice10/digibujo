# frozen_string_literal: true

require 'application_system_test_case'

class ComposerSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    visit timeline_path
  end

  test 'creates a text bullet through the shared composer' do
    editor = find('#timeline_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Fresh note')
    find('#timeline_composer .composer--submit-button').click

    assert_text 'Fresh note'
    assert_equal 'Text', @user.bullets.reload.last.bulletable_type
  end

  test 'shift f focuses the composer from elsewhere on the page' do
    assert_selector '#timeline_composer lexxy-editor.hotkey-hint[data-hotkey="F"]'
    find('body').send_keys([:shift, 'f'])

    assert_selector '#timeline_composer lexxy-editor .lexxy-editor__content:focus'
  end

  test 'toolbar buttons format the editor content' do
    editor = find('#timeline_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Formatted note')
    select_all_modifier = RUBY_PLATFORM.include?('darwin') ? :meta : :control
    editor.send_keys([select_all_modifier, 'a'])

    find('#timeline_composer [data-composer-editor-target="toolbarToggle"]').click
    find('#timeline_composer lexxy-toolbar button[name="bold"]').click

    assert_selector '#timeline_composer lexxy-editor .lexxy-editor__content strong', text: 'Formatted note'
  end

  test 'voice mode swaps successful controls and resets on exit' do
    find('#timeline_composer button[aria-label="Record voice memo"]').click

    assert_selector '#timeline_composer[data-composer-mode-value="recorder"]'
    assert_selector '#timeline_composer [data-composer-recorder-target="recordButton"]'
    assert_selector '#timeline_composer .composer--submit-button[disabled]'

    find('#timeline_composer button[aria-label="Back to text composer"]').click

    assert_selector '#timeline_composer[data-composer-mode-value="editor"]'
    assert_selector '#timeline_composer [data-composer-recorder-state="idle"]'
    assert_no_selector '#timeline_composer .composer--submit-button[disabled]'
  end

  test 'typing hides the recorder button' do
    editor = find('#timeline_composer lexxy-editor .lexxy-editor__content')
    recorder_button = '#timeline_composer button[aria-label="Record voice memo"]'

    assert_selector recorder_button
    editor.send_keys('Text draft')

    assert_no_selector recorder_button
  end

  test 'chat composer is the keyboard-safe final flex row' do
    assert_selector '.chat--window > .chat--surface > .chat--scroller[data-controller~="chat-scroll"]'
    assert_selector '.chat--window > .chat--surface > #timeline_composer_dock[data-controller~="chat-composer"] > #timeline_composer'
  end
end
