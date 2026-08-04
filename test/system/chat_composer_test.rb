# frozen_string_literal: true

require 'application_system_test_case'

class ChatComposerSystemTest < ApplicationSystemTestCase
  setup do
    Onboarding.new(user: users(:one)).complete
    @user = users(:one).reload
    sign_in_as(@user)
    # The composer remembers the last picked type; Capybara reuses the browser
    # between tests, so drop it or the previous test decides our default.
    page.execute_script('window.localStorage.clear()')
  end

  test 'shift f focuses the composer field' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '.composer--text-form-wrap.hotkey-hint[data-hotkey="Shift+F"]'
    assert_selector '.composer--record.hotkey-hint[data-hotkey="Shift+R"]'

    page.execute_script('document.activeElement?.blur()')
    page.execute_script(<<~JS)
      document.body.dispatchEvent(new KeyboardEvent('keydown', {
        key: 'f',
        code: 'KeyF',
        shiftKey: true,
        bubbles: true,
        cancelable: true
      }))
    JS

    assert page.evaluate_script(<<~JS)
      (() => {
        const editor = document.querySelector('#daylog_bullets_composer lexxy-editor')
        return editor === document.activeElement || editor?.contains(document.activeElement)
      })()
    JS
  end

  test 'cmd enter appends a note without leaving the daylog' do
    visit daylog_path(date: Date.current.iso8601)

    compose 'Buy oat milk'

    assert_text 'Buy oat milk'
    assert_current_path daylog_path(date: Date.current.iso8601)
    assert(@user.bullets.reload.any? { |bullet| bullet.body_as_text.strip == 'Buy oat milk' })
  end

  test 'plain enter does not send a note' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Still drafting')
    editor.send_keys(:enter)

    assert_equal 0, @user.bullets.reload.count
    assert_selector '#daylog_bullets_composer.composer--multiline'
  end

  test 'enter sends a task' do
    visit daylog_path(date: Date.current.iso8601)

    find('.composer--type-button').click
    find('.composer--type-option[data-composer-type="Task"]').click

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Buy oat milk')
    editor.send_keys(:enter)

    assert_text 'Buy oat milk'
    assert_equal 'Task', @user.bullets.reload.last.bulletable_type
  end

  test 'the composer clears itself after a send' do
    visit daylog_path(date: Date.current.iso8601)

    compose 'First line'
    assert_text 'First line'

    assert_selector '.composer--submit[disabled]'
    assert_selector '.composer--record'
    assert_equal '', find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content').text
  end

  test 'the mic hides while the field has text and returns when emptied' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '.composer--record'

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('A')

    assert_no_selector '.composer--record'

    editor.send_keys(:backspace)

    assert_selector '.composer--record'
  end

  test 'the picked type is remembered and drives the created bullet' do
    visit daylog_path(date: Date.current.iso8601)

    find('.composer--type-button').click
    find('.composer--type-option[data-composer-type="Task"]').click

    compose 'Buy oat milk'
    assert_text 'Buy oat milk'

    assert_equal 'Task', @user.bullets.reload.last.bulletable_type

    visit daylog_path(date: Date.current.iso8601)
    assert_selector '#daylog_bullets_composer[data-bullet-type="task"]'
  end

  test 'shift enter keeps writing instead of sending' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('First line')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')

    assert_selector '#daylog_bullets_composer.composer--multiline'
    assert_equal 0, @user.bullets.reload.count
  end

  test 'multiline chrome stays latched after the text shrinks back to one line' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('First line')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')
    assert_selector '#daylog_bullets_composer.composer--multiline'

    page.execute_script(<<~JS)
      document.querySelector('#daylog_bullets_composer lexxy-editor').value = '<p>Short</p>'
      document.querySelector('#daylog_bullets_composer lexxy-editor').dispatchEvent(new Event('lexxy:change'))
    JS

    assert_selector '#daylog_bullets_composer.composer--multiline'
  end

  test 'toolbar toggle is Note-only and clear waits for multiline' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '.composer--actions .composer--toolbar-toggle'
    assert_no_selector '.composer--actions .composer--upload'
    assert_no_selector '.composer--lead .composer--clear', visible: true
    assert_no_selector '#composer_toolbar > button[name=bold]', visible: true

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('First line')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')

    assert_selector '#daylog_bullets_composer.composer--multiline'
    assert_selector '.composer--actions .composer--toolbar-toggle'
    assert_selector '.composer--lead .composer--clear[aria-label="Clear draft"]'
    assert_no_selector '#composer_toolbar > button[name=bold]', visible: true
  end

  test 'an attachment latches multiline' do
    visit daylog_path(date: Date.current.iso8601)

    assert_no_selector '#daylog_bullets_composer.composer--multiline'
    assert_selector '.composer--actions .composer--toolbar-toggle'
    assert_no_selector '.composer--actions .composer--upload'

    page.execute_script(<<~JS)
      const editor = document.querySelector('#daylog_bullets_composer lexxy-editor')
      const content = editor.editorContentElement || editor.querySelector('.lexxy-editor__content')
      const figure = document.createElement('figure')
      figure.className = 'attachment attachment--file'
      content.appendChild(figure)
      editor.dispatchEvent(new Event('lexxy:change'))
    JS

    assert_selector '#daylog_bullets_composer.composer--multiline'
    assert_no_selector '#composer_toolbar > button[name=bold]', visible: true
  end

  test 'toolbar toggle is Note-only' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '.composer--actions .composer--toolbar-toggle'
    assert_no_selector '.composer--actions .composer--upload'
    assert_selector '.composer--type-button.button--secondary'

    find('.composer--type-button').click
    find('.composer--type-option[data-composer-type="Task"]').click

    assert_no_selector '.composer--toolbar-toggle', visible: true
  end

  test 'toolbar toggle reveals formatting under the field without remounting' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '#daylog_bullets_composer lexxy-editor[preset=note]'
    assert_selector '.composer--actions .composer--toolbar-toggle'
    assert_no_selector '.composer--actions .composer--upload'
    assert_no_selector '#composer_toolbar > button[name=bold]', visible: true
    assert_selector '#daylog_bullets_composer #composer_toolbar + .composer--text-form-wrap + .composer--chrome'

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Draft note')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')
    assert_selector '.composer--toolbar-toggle'
    assert_selector '.composer--lead .composer--clear[aria-label="Clear draft"]'
    assert_no_selector '#composer_toolbar > button[name=bold]', visible: true

    find('.composer--toolbar-toggle').click

    assert_selector '#daylog_bullets_composer.composer--toolbar'
    assert_selector '#composer_toolbar[aria-hidden="false"]'
    assert_selector '#daylog_bullets_composer lexxy-editor[preset=note]'
    assert_selector '#composer_toolbar > button[name=bold]'
    assert_selector '#composer_toolbar > button[name=file]'
    assert_selector '#composer_toolbar > button[name=image]'
    assert_selector '.composer--type-button', visible: true
    assert_selector '.composer--lead .composer--clear[aria-label="Clear draft"]'
    assert_text 'Draft note'
    assert_selector '#daylog_bullets_composer.composer--multiline .composer--chrome'

    find('.composer--toolbar-toggle').click

    assert_no_selector '#daylog_bullets_composer.composer--toolbar'
    assert_selector '#composer_toolbar[aria-hidden="true"]', visible: :all
    assert_selector '#daylog_bullets_composer.composer--multiline'
    assert_selector '#daylog_bullets_composer lexxy-editor[preset=note]'
    assert_no_selector '#composer_toolbar > button[name=bold]', visible: true
    assert_text 'Draft note'
    assert_selector '.composer--type-button', visible: true
  end

  test 'clear empties a multiline draft' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Draft note')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')

    assert_selector '.composer--lead .composer--clear[aria-label="Clear draft"]'
    find('.composer--lead .composer--clear').click

    assert_no_selector '#daylog_bullets_composer.composer--multiline'
    assert_no_selector '.composer--clear', visible: true
    assert_selector '.composer--submit[disabled]'
  end

  test 'shift r starts a voice recording from the focused composer' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '.composer--record'
    focus_composer

    page.execute_script(<<~JS)
      document.querySelector('#daylog_bullets_composer lexxy-editor').dispatchEvent(
        new KeyboardEvent('keydown', {
          key: 'R',
          code: 'KeyR',
          shiftKey: true,
          bubbles: true,
          cancelable: true
        })
      )
    JS

    assert_selector '#daylog_bullets_composer[data-bullet-type="voice"]'
    assert_selector '.composer--rail-recorder:not([hidden])'
    assert_selector '.composer--rail-recorder-pause'
    assert_no_selector '.composer--rail:not(.composer--rail-recorder)', visible: true
  end

  test 'the mic button records a voice bullet without touching the type picker' do
    visit daylog_path(date: Date.current.iso8601)

    find('.composer--record').click

    assert_selector '#daylog_bullets_composer[data-bullet-type="voice"]'
    assert_selector '.composer--rail-recorder:not([hidden])'
    assert_selector '.composer--rail-recorder-pause'
    assert_selector '.composer--rail-recorder-waveform'
    assert_no_selector '.composer--type-button', visible: true

    # MediaRecorder emits its first chunk after 250ms; wait until the countdown
    # has ticked once so the take actually has data.
    assert_selector '.composer--rail-recorder-remaining', text: '0:59'
    find('.composer--rail-recorder-pause').click

    assert_selector '.composer--rail-recorder .composer--submit:not([disabled])'
    find('.composer--rail-recorder .composer--submit').click

    assert_selector '.bullet[data-bullet-type="voice"]'
    assert_equal 'Voice', @user.bullets.reload.last.bulletable_type
    assert_selector '#daylog_bullets_composer[data-bullet-type="note"]'
    assert_selector '.composer--rail:not(.composer--rail-recorder)', visible: true
  end

  test 'shift tab cycles the bullet type while the editor is focused' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '#daylog_bullets_composer[data-bullet-type="note"]'
    focus_composer
    find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content').send_keys(%i[shift tab])

    assert_selector '#daylog_bullets_composer[data-bullet-type="task"]'

    find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content').send_keys(%i[shift tab])
    assert_selector '#daylog_bullets_composer[data-bullet-type="event"]'

    find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content').send_keys(%i[shift tab])
    assert_selector '#daylog_bullets_composer[data-bullet-type="note"]'
  end

  test 'shift control e toggles the Note formatting toolbar' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('First line')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')
    assert_selector '.composer--toolbar-toggle'

    page.execute_script(<<~JS)
      document.querySelector('#daylog_bullets_composer lexxy-editor').dispatchEvent(
        new KeyboardEvent('keydown', {
          key: 'E',
          code: 'KeyE',
          shiftKey: true,
          ctrlKey: true,
          bubbles: true,
          cancelable: true
        })
      )
    JS

    assert_selector '#daylog_bullets_composer.composer--toolbar'
    assert_selector '#composer_toolbar > button[name=bold]'
    assert_selector '#daylog_bullets_composer lexxy-editor[preset=note]'
  end

  test 'composer writes the keyboard spacing variable the stylesheet reads' do
    visit daylog_path(date: Date.current.iso8601)

    # #syncKeyboardInset runs on connect and on window resize; it sets the inset
    # unconditionally (0px without a real keyboard). Assert the *variable name*
    # the stylesheet reads is the one written.
    spacing = page.evaluate_script(<<~JS)
      document.querySelector('#daylog_bullets_composer')
        .style.getPropertyValue('--composer-keyboard-spacing')
    JS

    assert_equal '0px', spacing
  end

  private

  def compose(text)
    focus_composer
    editor = find('#daylog_bullets_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys(text)
    # Notes need Cmd/Ctrl+Enter; Task/Event send on plain Enter.
    type = page.evaluate_script(<<~JS)
      document.querySelector('#daylog_bullets_composer [data-chat-composer-target="typeElement"]')?.value
    JS
    if type == 'Note'
      editor.send_keys([modifier_key, :enter])
    else
      editor.send_keys(:enter)
    end
  end

  def focus_composer
    page.execute_script(<<~JS)
      document.querySelector('#daylog_bullets_composer lexxy-editor')?.focus()
    JS
  end

  def modifier_key
    RUBY_PLATFORM.match?(/darwin/i) ? :meta : :control
  end
end
