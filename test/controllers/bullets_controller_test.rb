# frozen_string_literal: true

require 'test_helper'

class BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = @user.bullets.create!(bulletable: Task.new(body: 'Original'))
  end

  test 'update turbo stream replaces bullet only' do
    assert_difference -> { Activity.count }, 1 do
      patch bullet_path(@bullet),
            params: { bullet: { bulletable_attributes: { body: 'Updated' } } },
            as: :turbo_stream
    end

    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_no_match(/turbo-stream action="after"/, response.body)
    assert_equal 'Updated', @bullet.reload.body.to_plain_text
    assert_equal 'updated', Activity.order(:created_at).last.action
  end

  test 'create redirects to the new bullet show page by default' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: 'Fresh task' },
               pops_on: Date.current.iso8601
             }
           }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create with another redirects to the new bullet show page' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             another: '1',
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: 'Rapid task' },
               pops_on: Date.current.iso8601
             }
           }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create tags bullet from project attachment in body' do
    project = create_project!(@user, name: 'Tagged')
    body_html = ActionText::Content.new('').append_attachables(project).to_html

      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: body_html },
               pops_on: Date.current.iso8601
             }
           }

    bullet = @user.bullets.order(:created_at).last
    assert_not_equal @bullet, bullet
    assert_includes bullet.projects, project
  end

  test 'create persists rich content in note body' do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Note',
               bulletable_attributes: { body: '<h1>Long detail</h1>' },
               pops_on: Date.current.iso8601
             }
           }

    bullet = @user.bullets.order(:created_at).last
    assert_match 'Long detail', bullet.body.to_plain_text
    assert_includes bullet.body.body_before_type_cast.to_s, '<h1'
  end

  test 'show renders note body' do
    note = @user.bullets.create!(bulletable: Note.new(body: '<p>Expanded content</p>'))

    get bullet_path(note)

    assert_response :success
    assert_match 'Expanded content', response.body
    assert_select '.bullet--rich-body', count: 0
  end

  test 'edit renders note body editor for note with saved content' do
    note = @user.bullets.create!(bulletable: Note.new(body: '<p>Expanded content</p>'))

    get edit_bullet_path(note)

    assert_response :success
    assert_select 'lexxy-editor[preset=note]', count: 1
    assert_match 'Expanded content', response.body
  end

  test 'create requires bullet type' do
    post bullets_path, params: { bullet: { bulletable_attributes: { body: 'No type' } } }

    assert_redirected_to new_bullet_path
    assert_equal 'Pick a bullet type first', flash[:alert]
  end

  test 'create allows blank body (becomes untitled)' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: '' }
             }
           }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create renders new with errors when invalid' do
    assert_no_difference -> { @user.bullets.count } do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Voice',
               bulletable_attributes: { body: '' }
             }
           }
    end

    assert_response :unprocessable_entity
    assert_select '.form--errors'
    assert_match 'can&#39;t be blank', response.body
  end

  test 'new without type renders full page type picker' do
    get new_bullet_path

    assert_response :success
    assert_select 'form.bullet-composer', count: 0
    assert_select '.bullet--composer-create-button'
    assert_select 'a[href*="bulletable_type=Task"]'
    assert_select 'a[href*="bulletable_type=Note"]'
    assert_select 'a[href*="bulletable_type=Event"]'
    assert_select 'a[href*="bulletable_type=Voice"]'
  end

  test 'new composer renders full page inline editor without frame-dismiss controls' do
    get new_bullet_path(bulletable_type: 'Task')

    assert_response :success
    assert_select 'form.bullet-composer'
    assert_select 'lexxy-editor[preset=inline]'
    assert_select '.bullet-composer--rail'
    assert_select '.bullet-composer--type-pill[data-bullet-type=?]', 'task', text: /Task/
    assert_select '.bullet-composer--type-dismiss', count: 0
    assert_select '.bullet-composer--rail-actions .bullet-composer--rail-submit button[type=submit]'
  end

  test 'new composer with Note type renders note editor' do
    get new_bullet_path(bulletable_type: 'Note')

    assert_response :success
    assert_select 'lexxy-editor[preset=note]'
    assert_select 'lexxy-editor[preset=inline]', false
    assert_select '.bullet-composer--type-pill[data-bullet-type=?]', 'note', text: /Note/
    assert_select '.bullet-composer--rail .mood-option', count: 4
  end

  test 'new composer renders without return_to field' do
    get new_bullet_path(bulletable_type: 'Task')
    assert_select "input[name='return_to']", count: 0
  end

  test 'new composer turbo frame request on mobile renders shared form in matching frame' do
    mobile_ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'

    get new_bullet_path(bulletable_type: 'Task', pops_on: Date.current),
        headers: { 'Turbo-Frame' => 'bullet_composer', 'User-Agent' => mobile_ua }

    assert_response :success
    assert_select 'turbo-frame#bullet_composer form.bullet-composer'
    assert_select 'lexxy-editor[preset=inline]'
    assert_select 'dialog', count: 0
  end

  test 'create sets note mood from bulletable_attributes' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             bulletable_attributes: { body: 'Moody note', mood: 'inspired' },
             pops_on: Date.current.iso8601
           }
         }

    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Note', bullet.bulletable_type
    assert_equal 'inspired', bullet.bulletable.mood
  end

  test 'update changes note mood via bulletable_attributes' do
    note = @user.bullets.create!(bulletable: Note.new(mood: 'positive', body: 'Existing note'))

    patch bullet_path(note),
          params: {
            bullet: {
              bulletable_type: 'Note',
              bulletable_attributes: { body: 'Updated body', mood: 'frustrated' }
            }
          },
          as: :turbo_stream

    assert_response :success
    assert_equal 'frustrated', note.reload.bulletable.mood
    assert_equal 'Updated body', note.body.to_plain_text
  end

  test 'create with non-Note type ignores stale bulletable_attributes' do
    # Simulates user picking a mood (Note), then switching to Task in the same form.
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: 'Stale mood', mood: 'inspired' },
               pops_on: Date.current.iso8601
             }
           }

    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Task', bullet.bulletable_type
    # Task has no mood column; the per-type permitted attrs stripped it before assignment.
    assert_not bullet.bulletable.respond_to?(:mood)
  end

  test 'edit redirects voice bullets to show' do
    blob = create_blob!(filename: 'voice.webm', content_type: 'audio/webm')
    bullet = @user.bullets.create!(
      bulletable_type: 'Voice',
      bulletable_attributes: { body: 'Voice caption', recording: blob.signed_id, duration_seconds: 5 }
    )

    get edit_bullet_path(bullet)

    assert_redirected_to bullet_path(bullet)
  end

  test 'update redirects voice bullets to show' do
    blob = create_blob!(filename: 'voice.webm', content_type: 'audio/webm')
    bullet = @user.bullets.create!(
      bulletable_type: 'Voice',
      bulletable_attributes: { body: 'Voice caption', recording: blob.signed_id, duration_seconds: 5 }
    )

    patch bullet_path(bullet), params: { bullet: { bulletable_attributes: { body: 'Changed' } } }

    assert_redirected_to bullet_path(bullet)
    assert_equal 'Voice caption', bullet.reload.body.to_plain_text
  end

  private

  def create_blob!(filename:, content_type:, io: StringIO.new('file contents'))
    ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: filename,
      content_type: content_type
    )
  end
end
