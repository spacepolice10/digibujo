# frozen_string_literal: true

require 'application_system_test_case'

class ComposerSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    visit bullets_path
  end

  test 'creates a text bullet through the shared composer' do
    editor = find('#timeline_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Fresh note')
    find('#timeline_composer .composer--submit-button').click

    assert_text 'Fresh note'
    assert_equal 'Fresh note', @user.bullets.reload.last.body_as_text
  end

  test 'shift f focuses the composer from elsewhere on the page' do
    assert_selector '#timeline_composer lexxy-editor.hotkey-hint[data-hotkey="F"]'
    find('body').send_keys([:shift, 'f'])

    assert_selector '#timeline_composer lexxy-editor .lexxy-editor__content:focus'
  end

  test 'the editor has no formatting toolbar' do
    assert_selector '#timeline_composer lexxy-editor'
    assert_no_selector '#timeline_composer lexxy-toolbar'
    assert_no_selector '#timeline_composer [aria-label="Toggle formatting toolbar"]'
  end

  test 'typing swaps the paperclip for the send button' do
    editor = find('#timeline_composer lexxy-editor .lexxy-editor__content')
    send = '#timeline_composer .composer--submit-button'
    attach = '#timeline_composer button[aria-label="Attach file"]'

    assert_selector attach
    assert_no_selector send

    editor.send_keys('Text draft')

    assert_selector send
    assert_no_selector attach

    editor.send_keys(*([:backspace] * 'Text draft'.length))

    assert_selector attach
    assert_no_selector send
  end

  test 'chat composer docks over the full-height scroller' do
    assert_selector '.chat--window > .chat--scroller[data-controller~="chat-scroll"]'
    assert_selector '.chat--window > #timeline_composer_dock[data-controller~="chat-composer"] > #timeline_composer'
  end
end
