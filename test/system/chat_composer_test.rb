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

    assert_selector '.composer--field.hotkey-hint[data-hotkey="Shift+F"]'
    assert_selector '.composer--record.hotkey-hint[data-hotkey="Shift+R"]'

    page.execute_script("document.activeElement?.blur()")
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
        const editor = document.querySelector('#bullet_composer lexxy-editor')
        return editor === document.activeElement || editor?.contains(document.activeElement)
      })()
    JS
  end

  test 'enter appends the bullet without leaving the daylog' do
    visit daylog_path(date: Date.current.iso8601)

    compose 'Buy oat milk'

    assert_text 'Buy oat milk'
    assert_current_path daylog_path(date: Date.current.iso8601)
    assert(@user.bullets.reload.any? { |bullet| bullet.body_as_text.strip == 'Buy oat milk' })
  end

  test 'the composer clears itself after a send' do
    visit daylog_path(date: Date.current.iso8601)

    compose 'First line'
    assert_text 'First line'

    assert_selector '.composer--submit[disabled]'
    assert_selector '.composer--record'
    assert_equal '', find('#bullet_composer lexxy-editor .lexxy-editor__content').text
  end

  test 'the mic hides while the field has text and returns when emptied' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '.composer--record'

    focus_composer
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
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
    assert_selector '#bullet_composer[data-bullet-type="task"]'
  end

  test 'shift enter keeps writing instead of sending' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('First line')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')

    assert_selector '#bullet_composer.composer--multiline'
    assert_equal 0, @user.bullets.reload.count
  end

  test 'multiline chrome stays latched after the text shrinks back to one line' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('First line')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')
    assert_selector '#bullet_composer.composer--multiline'

    page.execute_script(<<~JS)
      document.querySelector('#bullet_composer lexxy-editor').value = '<p>Short</p>'
      document.querySelector('#bullet_composer lexxy-editor').dispatchEvent(new Event('lexxy:change'))
    JS

    assert_selector '#bullet_composer.composer--multiline'
  end

  test 'toolbar toggle and clear appear for Note once the draft wraps to two lines' do
    visit daylog_path(date: Date.current.iso8601)

    assert_no_selector '.composer--actions .composer--toolbar-toggle', visible: true
    assert_no_selector '.composer--actions .composer--clear', visible: true
    assert_selector '.composer--actions .composer--upload'
    assert_no_selector '#bullet_composer button[name=bold]', visible: true

    focus_composer
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('First line')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')

    assert_selector '#bullet_composer.composer--multiline'
    assert_selector '.composer--actions .composer--toolbar-toggle'
    assert_selector '.composer--actions .composer--clear'
    assert_selector '.composer--actions .composer--upload'
    assert_no_selector '#bullet_composer button[name=bold]', visible: true
  end

  test 'an attachment latches multiline while upload stays in actions' do
    visit daylog_path(date: Date.current.iso8601)

    assert_no_selector '#bullet_composer.composer--multiline'
    assert_selector '.composer--actions .composer--upload'

    page.execute_script(<<~JS)
      const editor = document.querySelector('#bullet_composer lexxy-editor')
      const content = editor.editorContentElement || editor.querySelector('.lexxy-editor__content')
      const figure = document.createElement('figure')
      figure.className = 'attachment attachment--file'
      content.appendChild(figure)
      editor.dispatchEvent(new Event('lexxy:change'))
    JS

    assert_selector '#bullet_composer.composer--multiline'
    assert_selector '.composer--actions .composer--upload'
    assert_no_selector '#bullet_composer button[name=bold]', visible: true
  end

  test 'toolbar toggle and upload are Note-only' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '.composer--actions .composer--upload'
    assert_selector '.composer--type-button.button--secondary'

    find('.composer--type-button').click
    find('.composer--type-option[data-composer-type="Task"]').click

    assert_no_selector '.composer--actions .composer--upload', visible: true
    assert_no_selector '.composer--toolbar-toggle', visible: true
  end

  test 'toolbar toggle reveals formatting without remounting the editor' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '#bullet_composer lexxy-editor[preset=note]'
    assert_selector '.composer--actions .composer--upload'
    assert_no_selector '#bullet_composer button[name=bold]', visible: true
    assert_no_selector '.composer--actions .composer--toolbar-toggle', visible: true

    focus_composer
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Draft note')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')
    assert_selector '.composer--toolbar-toggle'
    assert_selector '.composer--clear'
    assert_no_selector '#bullet_composer button[name=bold]', visible: true
    assert_selector '.composer--actions .composer--upload'

    find('.composer--toolbar-toggle').click

    assert_selector '#bullet_composer.composer--toolbar'
    assert_selector '#bullet_composer lexxy-editor[preset=note]'
    assert_selector '.composer--actions .composer--upload'
    assert_selector '#bullet_composer button[name=bold]'
    assert_no_selector '.composer--type-button', visible: true
    assert_equal 'fixed', page.evaluate_script("getComputedStyle(document.querySelector('#bullet_composer')).position")
    assert_text 'Draft note'

    find('.composer--toolbar-toggle').click

    assert_no_selector '#bullet_composer.composer--toolbar'
    assert_selector '#bullet_composer.composer--multiline'
    assert_selector '#bullet_composer lexxy-editor[preset=note]'
    assert_selector '.composer--actions .composer--upload'
    assert_no_selector '#bullet_composer button[name=bold]', visible: true
    assert_text 'Draft note'
    assert_selector '.composer--type-button', visible: true
  end

  test 'clear empties a multiline draft' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Draft note')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')

    assert_selector '.composer--clear'
    find('.composer--clear').click

    assert_no_selector '#bullet_composer.composer--multiline'
    assert_no_selector '.composer--clear', visible: true
    assert_selector '.composer--submit[disabled]'
  end

  test 'shift r starts a voice recording from the focused composer' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '.composer--record'
    focus_composer

    page.execute_script(<<~JS)
      document.querySelector('#bullet_composer lexxy-editor').dispatchEvent(
        new KeyboardEvent('keydown', {
          key: 'R',
          code: 'KeyR',
          shiftKey: true,
          bubbles: true,
          cancelable: true
        })
      )
    JS

    assert_selector '#bullet_composer[data-bullet-type="voice"]'
    assert_selector '.composer--voice:not([hidden])'
    assert_selector '.composer--voice-pause'
    assert_no_selector '.composer--row:not(.composer--voice)', visible: true
  end

  test 'the mic button records a voice bullet without touching the type picker' do
    visit daylog_path(date: Date.current.iso8601)

    find('.composer--record').click

    assert_selector '#bullet_composer[data-bullet-type="voice"]'
    assert_selector '.composer--voice:not([hidden])'
    assert_selector '.composer--voice-pause'
    assert_selector '.composer--voice-waveform'
    assert_no_selector '.composer--type-button', visible: true

    # MediaRecorder emits its first chunk after 250ms; wait until the countdown
    # has ticked once so the take actually has data.
    assert_selector '.composer--voice-remaining', text: '0:59'
    find('.composer--voice-pause').click

    assert_selector '.composer--voice .composer--submit:not([disabled])'
    find('.composer--voice .composer--submit').click

    assert_selector '.bullet[data-bullet-type="voice"]'
    assert_equal 'Voice', @user.bullets.reload.last.bulletable_type
    assert_selector '#bullet_composer[data-bullet-type="note"]'
    assert_selector '.composer--row:not(.composer--voice)', visible: true
  end

  test 'shift tab cycles the bullet type while the editor is focused' do
    visit daylog_path(date: Date.current.iso8601)

    assert_selector '#bullet_composer[data-bullet-type="note"]'
    focus_composer
    find('#bullet_composer lexxy-editor .lexxy-editor__content').send_keys(%i[shift tab])

    assert_selector '#bullet_composer[data-bullet-type="task"]'

    find('#bullet_composer lexxy-editor .lexxy-editor__content').send_keys(%i[shift tab])
    assert_selector '#bullet_composer[data-bullet-type="event"]'

    find('#bullet_composer lexxy-editor .lexxy-editor__content').send_keys(%i[shift tab])
    assert_selector '#bullet_composer[data-bullet-type="note"]'
  end

  test 'shift control e toggles the Note formatting toolbar' do
    visit daylog_path(date: Date.current.iso8601)

    focus_composer
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('First line')
    editor.send_keys(%i[shift enter])
    editor.send_keys('Second line')
    assert_selector '.composer--toolbar-toggle'

    page.execute_script(<<~JS)
      document.querySelector('#bullet_composer lexxy-editor').dispatchEvent(
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

    assert_selector '#bullet_composer.composer--toolbar'
    assert_selector '#bullet_composer lexxy-editor[preset=note]'
  end

  private

  def compose(text)
    focus_composer
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys(text)
    editor.send_keys(:enter)
  end

  def focus_composer
    page.execute_script(<<~JS)
      document.querySelector('#bullet_composer lexxy-editor')?.focus()
    JS
  end
end
