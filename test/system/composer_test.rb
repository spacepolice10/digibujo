# frozen_string_literal: true

require 'application_system_test_case'

class ComposerSystemTest < ApplicationSystemTestCase
  setup do
    Onboarding.new(user: users(:one)).complete
    @user = users(:one).reload
    sign_in_as(@user)
    visit daylog_path(date: Date.current.iso8601)
  end

  test 'creates a text bullet through the shared composer' do
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Fresh note')
    find('#daylog_bullets_composer .composer--submit-button').click

    assert_text 'Fresh note'
    assert_equal 'Note', @user.bullets.reload.last.bulletable_type
  end

  test 'shift tab cycles the bullet type while editing' do
    editor_host = find('#daylog_bullets_composer lexxy-editor')
    editor = editor_host.find('.lexxy-editor__content')
    editor.click
    editor.send_keys([:shift, :tab])

    assert_selector '#daylog_bullets_composer select[name="bullet[bulletable_type]"] option[value="Task"]:checked'
  end

  test 'shift f focuses the composer from elsewhere on the page' do
    assert_selector '#daylog_bullets_composer lexxy-editor.hotkey-hint[data-hotkey="F"]'
    find('body').send_keys([:shift, 'f'])

    assert_selector '#daylog_bullets_composer lexxy-editor .lexxy-editor__content:focus'
  end

  test 'voice mode swaps successful controls and resets on exit' do
    find('#daylog_bullets_composer button[aria-label="Record voice memo"]').click

    assert_selector '#daylog_bullets_composer[data-composer-mode-value="recorder"]'
    assert_selector '#daylog_bullets_composer [data-composer-recorder-target="recordButton"]'
    assert_selector '#daylog_bullets_composer .composer--submit-button[disabled]'

    find('#daylog_bullets_composer button[aria-label="Back to text composer"]').click

    assert_selector '#daylog_bullets_composer[data-composer-mode-value="editor"]'
    assert_selector '#daylog_bullets_composer [data-composer-recorder-state="idle"]'
    assert_no_selector '#daylog_bullets_composer .composer--submit-button[disabled]'
  end

  test 'chat composer is the keyboard-safe final flex row' do
    assert_selector '.chat--window > .chat--surface > .chat--scroller[data-controller~="chat-scroll"]'
    assert_selector '.chat--window > .chat--surface > #daylog_composer[data-controller~="chat-composer"] > #daylog_bullets_composer'
  end
end
