# frozen_string_literal: true

require 'test_helper'

class BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @daylog = ensure_daylog!(@user)
    @bullet = create_bullet!(@user, bulletable: Task.new(body: 'Original'))
  end

  test 'update turbo stream replaces bullet only' do
    assert_no_difference -> { Activity.count } do
      patch bullet_path(@bullet),
            params: {
              bullet: {
                bulletable_attributes: { id: @bullet.bulletable_id, body: 'Updated' }
              }
            },
            as: :turbo_stream
    end

    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_no_match(/turbo-stream action="after"/, response.body)
    assert_equal 'Updated', @bullet.reload.body_as_text
  end

  test 'create redirects to the originating daylog' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: 'Fresh task' },
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }
    end

    assert_redirected_to daylog_path(date: Date.current.iso8601)
  end

  test 'create redirects to originating page even when turbo stream is preferred' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: 'Full page task' },
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           },
           as: :turbo_stream
    end

    assert_redirected_to daylog_path(date: Date.current.iso8601)
  end

  test 'inline composer create appends the row and drops the empty state' do
    container = ActionView::RecordIdentifier.dom_id(@user.daylog, :bullets_container)

    post bullets_path,
         params: {
           inline_composer: '1',
           bullet: {
             bulletable_type: 'Task',
             bulletable_attributes: { body: '<p>Chat task</p>' },
             pops_on: Date.current.iso8601,
             bucket_id: @daylog.id
           }
         },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'Chat task', response.body
    assert_match %(turbo-stream action="remove" target="no_bullets_container"), response.body
    assert_no_match 'collection--date-pill', response.body
  end

  test 'inline composer create on a collection prepends a date pill for a new day' do
    collection = create_collection!(@user, name: 'Inbox')
    create_bullet!(@user, bucket: collection.bucket, pops_on: nil, bulletable: Note.new(body: 'Yesterday'),
                   created_at: 1.day.ago)
    container = ActionView::RecordIdentifier.dom_id(collection, :bullets_container)

    post bullets_path,
         params: {
           inline_composer: '1',
           bullet: {
             bulletable_type: 'Note',
             bulletable_attributes: { body: '<p>Fresh today</p>' },
             bucket_id: collection.bucket.id
           }
         },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'collection--date-pill', response.body
    assert_match 'Today', response.body
    assert_match 'Fresh today', response.body
  end

  test 'inline composer create on a collection skips the date pill for the same day' do
    collection = create_collection!(@user, name: 'Inbox')
    create_bullet!(@user, bucket: collection.bucket, pops_on: nil, bulletable: Note.new(body: 'Earlier today'),
                   created_at: 1.hour.ago)
    container = ActionView::RecordIdentifier.dom_id(collection, :bullets_container)

    post bullets_path,
         params: {
           inline_composer: '1',
           bullet: {
             bulletable_type: 'Note',
             bulletable_attributes: { body: '<p>Later today</p>' },
             bucket_id: collection.bucket.id
           }
         },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'Later today', response.body
    assert_no_match 'collection--date-pill', response.body
  end

  test 'inline composer create reports validation errors as a toast' do
    post bullets_path,
         params: {
           inline_composer: '1',
           bullet: {
             bulletable_type: 'Voice',
             bulletable_attributes: { body: 'No recording attached' },
             bucket_id: @daylog.id
           }
         },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match %(turbo-stream action="update" target="toasts"), response.body
    assert_match 'Recording', response.body
  end

  test 'create tags note from project attachment in body' do
    project = create_project!(@user, name: 'Tagged')
    body_html = ActionText::Content.new('').append_attachables(project).to_html

      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Note',
               bulletable_attributes: { body: body_html },
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }

    bullet = @user.bullets.order(:created_at).last
    assert_not_equal @bullet, bullet
    assert_includes bullet.projects, project
  end

  test 'create tags task from project attachment in body' do
    project = create_project!(@user, name: 'Tagged task')
    body_html = ActionText::Content.new('').append_attachables(project).to_html

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             bulletable_attributes: { body: body_html },
             pops_on: Date.current.iso8601,
             bucket_id: @daylog.id
           }
         }

    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Task', bullet.bulletable_type
    assert_includes bullet.projects, project
  end

  test 'create persists rich content in note body' do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Note',
               bulletable_attributes: { body: '<h1>Long detail</h1>' },
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }

    bullet = @user.bullets.order(:created_at).last
    assert_match 'Long detail', bullet.body.to_plain_text
    assert_includes bullet.body.body_before_type_cast.to_s, '<h1'
  end

  test 'show renders note body' do
    note = create_bullet!(@user, bulletable: Note.new(body: '<p>Expanded content</p>'))

    get bullet_path(note)

    assert_response :success
    assert_match 'Expanded content', response.body
    assert_select '.bullet--rich-body', count: 0
  end

  test 'show renders unarchive for archived bullet' do
    bullet = create_bullet!(@user, bulletable: Task.new(body: 'Archived task'))
    bullet.archive!

    get bullet_path(bullet)

    assert_response :success
    assert_select '.layout--surface-header form[action=?][method=post]', archive_path do
      assert_select 'input[name=_method][value=delete]'
      assert_select 'button', text: /^Unarchive$/
    end
  end

  test 'edit renders note body editor for note with saved content' do
    note = create_bullet!(@user, bulletable: Note.new(body: '<p>Expanded content</p>'))

    get edit_bullet_path(note)

    assert_response :success
    assert_select '.layout--surface'
    assert_select '.bullet--header h2', text: 'Edit bullet'
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
               bulletable_attributes: { body: '' },
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to daylog_path(date: Date.current.iso8601)
  end

  test 'create renders new with errors when invalid' do
    assert_no_difference -> { @user.bullets.count } do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Voice',
               bulletable_attributes: { body: '' },
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }
    end

    assert_response :unprocessable_entity
    assert_select '.form--errors'
    assert_match 'can&#39;t be blank', response.body
  end

  test 'new without type asks to pick a type' do
    get new_bullet_path

    assert_response :success
    assert_select 'form.bullets-form', count: 0
    assert_select '.bullets-form--dock'
    assert_select 'a[aria-label=?]', 'Add Task'
  end

  test 'new composer renders full page inline editor' do
    get new_bullet_path(bulletable_type: 'Task')

    assert_response :success
    assert_select 'form.bullets-form'
    assert_select 'lexxy-editor[preset=inline]'
    assert_select '.bullets-form--rail'
    assert_select '.bullets-form--type-pill[data-bullet-type=?]', 'task', text: /Task/
    assert_select '.bullets-form--rail-submit button[type=submit]'
  end

  test 'new composer with Note type renders note editor' do
    get new_bullet_path(bulletable_type: 'Note')

    assert_response :success
    assert_select 'lexxy-editor[preset=note]'
    assert_select 'lexxy-editor[preset=inline]', false
    assert_select '.bullets-form--type-pill[data-bullet-type=?]', 'note', text: /Note/
  end

  test 'new composer renders navigational back link from bucket' do
    get new_bullet_path(bulletable_type: 'Task', pops_on: Date.current, bucket_id: @daylog.id)

    assert_response :success
    assert_select 'a.bullets-form--type-dismiss[data-turbo-frame=_top][href=?]',
                  daylog_path(date: Date.current.iso8601)
    assert_select "input[name='return_to']", count: 0
  end

  test 'create redirects to originating collection' do
    collection = create_collection!(@user, name: 'Inbox')

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: 'Collection task' },
               bucket_id: collection.bucket.id
             }
           }
    end

    assert_redirected_to collection_path(collection)
  end

  test 'create with non-Note type ignores stale bulletable_attributes' do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               bulletable_attributes: { body: 'Stale mood', mood: 'inspired' },
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }

    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Task', bullet.bulletable_type
    assert_not bullet.bulletable.respond_to?(:mood)
  end

  test 'edit redirects voice bullets to show' do
    blob = create_blob!(filename: 'voice.webm', content_type: 'audio/webm')
    bullet = create_bullet!(@user,
      bulletable_type: 'Voice',
      bulletable_attributes: { body: 'Voice caption', recording: blob.signed_id, duration_seconds: 5 }
    )

    get edit_bullet_path(bullet)

    assert_redirected_to bullet_path(bullet)
  end

  test 'update redirects voice bullets to show' do
    blob = create_blob!(filename: 'voice.webm', content_type: 'audio/webm')
    bullet = create_bullet!(@user,
      bulletable_type: 'Voice',
      bulletable_attributes: { body: 'Voice caption', recording: blob.signed_id, duration_seconds: 5 }
    )

    patch bullet_path(bullet), params: { bullet: { bulletable_attributes: { body: 'Changed' } } }

    assert_redirected_to bullet_path(bullet)
    assert_equal 'Voice caption', bullet.reload.body_as_text
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
