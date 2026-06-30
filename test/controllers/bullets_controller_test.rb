# frozen_string_literal: true

require 'test_helper'

class BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Original')
  end

  test 'update turbo stream replaces bullet only' do
    assert_difference -> { Activity.count }, 1 do
      patch bullet_path(@bullet),
            params: { bullet: { body: 'Updated' } },
            as: :turbo_stream
    end

    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_no_match(/turbo-stream action="after"/, response.body)
    assert_equal 'Updated', @bullet.reload.body.to_plain_text
    assert_equal 'updated', Activity.order(:created_at).last.action
  end

  test 'create turbo stream appends bullet into bullets container' do
    collection = create_collection!(@user, name: 'Fresh collection')

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: 'Fresh task',
             pops_on: Date.current.iso8601,
             bucket_id: collection.bucket.id
           }
         },
         as: :turbo_stream

    assert_response :success
    assert_turbo_stream action: 'append', target: 'bullets'
    assert_no_turbo_stream action: 'replace', target: 'bullet_composer'
  end

  test 'create note turbo stream appends bullet into bullets container' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             body: 'A long note',
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    assert_response :success
    assert_turbo_stream action: 'append', target: 'bullets'
    assert_no_turbo_stream action: 'replace', target: 'bullet_composer'
  end

  test 'create with another keeps composer open' do
    post bullets_path,
         params: {
           another: '1',
           bullet: {
             bulletable_type: 'Task',
             body: 'Rapid task',
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    assert_response :success
    assert_turbo_stream action: 'append', target: 'bullets'
    assert_no_turbo_stream action: 'replace', target: 'bullet_composer'
  end

  test 'create tags bullet from project attachment in body' do
    project = create_project!(@user, name: 'Tagged')
    body_html = ActionText::Content.new('').append_attachables(project).to_html

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: body_html,
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    assert_response :success
    bullet = @user.bullets.order(:created_at).last
    assert_not_equal @bullet, bullet
    assert_includes bullet.projects, project
  end

  test 'create persists rich content in note body' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             body: '<h1>Long detail</h1>',
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    bullet = @user.bullets.order(:created_at).last
    assert_match 'Long detail', bullet.body.to_plain_text
    assert_includes bullet.body.body_before_type_cast.to_s, '<h1'
  end

  test 'show renders note body' do
    note = @user.bullets.create!(bulletable: Note.create!, body: '<p>Expanded content</p>')

    get bullet_path(note)

    assert_response :success
    assert_match 'Expanded content', response.body
    assert_select '.bullet--rich-body', count: 0
  end

  test 'edit renders note body editor for note with saved content' do
    note = @user.bullets.create!(bulletable: Note.create!, body: '<p>Expanded content</p>')

    get edit_bullet_path(note)

    assert_response :success
    assert_select 'lexxy-editor[preset=note]', count: 1
    assert_match 'Expanded content', response.body
  end

  test 'create requires bullet type' do
    post bullets_path,
         params: { bullet: { body: 'No type' } },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match 'Bullet type is required', response.body
  end

  test 'create allows blank body (becomes untitled)' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               body: ''
             }
           },
           as: :turbo_stream
    end

    assert_response :success
    assert_turbo_stream action: 'append', target: 'bullets'
    assert_no_turbo_stream action: 'replace', target: 'bullet_composer'
  end

  test 'new without type renders type picker' do
    get new_bullet_path

    assert_response :success
    assert_select 'form.bullet-composer', count: 0
    assert_select '.bullet--composer-create-button'
    assert_select 'a[href*="bulletable_type=Task"]'
    assert_select 'a[href*="bulletable_type=Note"]'
    assert_select 'a[href*="bulletable_type=Event"]'
    assert_no_match 'bulletable_type=Title', response.body
  end

  test 'new composer renders inline editor with rail layout' do
    get new_bullet_path(bulletable_type: 'Task')

    assert_response :success
    assert_select 'lexxy-editor[preset=inline]'
    assert_select '.bullet-composer--rail'
    assert_select '.bullet-composer--type-pill[data-bullet-type=?]', 'task', text: /Task/
    assert_select '.bullet-composer--type-dismiss[data-action=?]', 'composer#cancel'
    assert_select '.bullet-composer--rail-actions'
    assert_select 'select.bullet-composer-type-select', count: 0
    assert_select '.bullet-composer--rail .mood-option', count: 0
    assert_select '.bullet-composer--rail-actions .bullet-composer--rail-submit button[type=submit]'
    assert_select '.bullet-composer--footer', count: 0
  end

  test 'new composer with Note type renders note editor' do
    get new_bullet_path(bulletable_type: 'Note')

    assert_response :success
    assert_select 'form.bullet-composer[data-action*="keydown.enter+meta->composer#submit"]'
    assert_select 'lexxy-editor[preset=note]'
    assert_select 'lexxy-editor[preset=inline]', false
    assert_select '.bullet-composer--type-pill[data-bullet-type=?]', 'note', text: /Note/
    assert_select '.bullet-composer--rail .mood-option', count: 4
  end

  test 'create sets note mood from bulletable_attributes' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             body: 'Moody note',
             pops_on: Date.current.iso8601,
             bulletable_attributes: { mood: 'inspired' }
           }
         },
         as: :turbo_stream

    assert_response :success
    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Note', bullet.bulletable_type
    assert_equal 'inspired', bullet.bulletable.mood
  end

  test 'update changes note mood via bulletable_attributes' do
    note = @user.bullets.create!(bulletable: Note.create!(mood: 'positive'), body: 'Existing note')

    patch bullet_path(note),
          params: {
            bullet: {
              bulletable_type: 'Note',
              body: 'Updated body',
              bulletable_attributes: { mood: 'frustrated' }
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
             body: 'Stale mood',
             pops_on: Date.current.iso8601,
             bulletable_attributes: { mood: 'inspired' }
           }
         },
         as: :turbo_stream

    assert_response :success
    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Task', bullet.bulletable_type
    # Task has no mood column; the per-type permitted attrs stripped it before assignment.
    assert_not bullet.bulletable.respond_to?(:mood)
  end

  test 'edit redirects voice bullets to show' do
    blob = create_blob!(filename: 'voice.webm', content_type: 'audio/webm')
    bullet = @user.bullets.create!(
      bulletable_type: 'Voice',
      body: 'Voice caption',
      bulletable_attributes: { recording: blob.signed_id, duration_seconds: 5 }
    )

    get edit_bullet_path(bullet)

    assert_redirected_to bullet_path(bullet)
  end

  test 'update redirects voice bullets to show' do
    blob = create_blob!(filename: 'voice.webm', content_type: 'audio/webm')
    bullet = @user.bullets.create!(
      bulletable_type: 'Voice',
      body: 'Voice caption',
      bulletable_attributes: { recording: blob.signed_id, duration_seconds: 5 }
    )

    patch bullet_path(bullet), params: { bullet: { body: 'Changed' } }

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
