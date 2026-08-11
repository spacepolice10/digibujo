# frozen_string_literal: true

require 'test_helper'

class BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @daylog = ensure_daylog!(@user)
    @bullet = create_bullet!(@user, bulletable: Task.new, body: 'Original')
  end

  test 'update turbo stream replaces bullet only' do
    assert_no_difference -> { Activity.count } do
      patch bullet_path(@bullet),
            params: {
              bullet: {
                body: 'Updated', bulletable_attributes: { id: @bullet.bulletable_id }
              }
            },
            as: :turbo_stream
    end

    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_no_match(/turbo-stream action="after"/, response.body)
    assert_equal 'Updated', @bullet.reload.body_as_text
  end

  test 'html create redirects to the bullet show' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               body: 'Fresh task',
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'turbo stream create appends the row' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               body: 'Stream task',
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           },
           headers: { 'Turbo-Frame' => 'daylog_bullets_composer' },
           as: :turbo_stream
    end

    assert_response :success
    target = dom_id(@daylog, Date.current)
    assert_match %(turbo-stream action="append" target="#{target}"), response.body
    assert_match 'Stream task', response.body
  end

  test 'composer create appends the row and drops the empty state' do
    container = dom_id(@daylog, Date.current)

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: '<p>Chat task</p>',
             pops_on: Date.current.iso8601,
             bucket_id: @daylog.id
           }
         },
         headers: { 'Turbo-Frame' => 'daylog_bullets_composer' },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'Chat task', response.body
    assert_match %(turbo-stream action="remove" target="no_bullets_container"), response.body
  end

  test 'composer create on a collection appends without a date pill' do
    collection = create_collection!(@user, name: 'Inbox')
    create_bullet!(@user, bucket: collection.bucket, pops_on: nil, bulletable: Note.new, body: 'Yesterday',
                   created_at: 1.day.ago)
    container = ActionView::RecordIdentifier.dom_id(collection.bucket, nil)
    composer = ActionView::RecordIdentifier.dom_id(collection, :bullets_composer)

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             body: '<p>Fresh today</p>',
             bucket_id: collection.bucket.id
           }
         },
         headers: { 'Turbo-Frame' => composer },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'Fresh today', response.body
    assert_no_match 'collection--date-pill', response.body
  end

  test 'composer create on a collection skips the date pill for the same day' do
    collection = create_collection!(@user, name: 'Inbox')
    create_bullet!(@user, bucket: collection.bucket, pops_on: nil, bulletable: Note.new, body: 'Earlier today',
                   created_at: 1.hour.ago)
    container = ActionView::RecordIdentifier.dom_id(collection, :bullets_container)
    composer = ActionView::RecordIdentifier.dom_id(collection, :bullets_composer)

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             body: '<p>Later today</p>',
             bucket_id: collection.bucket.id
           }
         },
         headers: { 'Turbo-Frame' => composer },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'Later today', response.body
    assert_no_match 'collection--date-pill', response.body
  end

  test 'composer create reports validation errors as a toast' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Voice',
             body: 'No recording attached',
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
               body: body_html,
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
             body: body_html,
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
               body: '<h1>Long detail</h1>',
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }

    bullet = @user.bullets.order(:created_at).last
    assert_match 'Long detail', bullet.body.to_plain_text
    assert_includes bullet.body.body_before_type_cast.to_s, '<h1'
  end

  test 'show renders note body' do
    note = create_bullet!(@user, bulletable: Note.new, body: '<p>Expanded content</p>')

    get bullet_path(note)

    assert_response :success
    assert_match 'Expanded content', response.body
    assert_select '.bullet--rich-body', count: 0
  end

  test 'show renders unarchive for archived bullet' do
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Archived task')
    bullet.archive!

    get bullet_path(bullet)

    assert_response :success
    assert_select '.layout--surface-header form[action=?][method=post]', archive_path do
      assert_select 'input[name=_method][value=delete]'
      assert_select 'button', text: /^Unarchive$/
    end
  end

  test 'edit renders note body editor for note with saved content' do
    note = create_bullet!(@user, bulletable: Note.new, body: '<p>Expanded content</p>')

    get edit_bullet_path(note)

    assert_response :success
    assert_select '.layout--surface'
    assert_select '.bullet--header h2', text: 'Edit bullet'
    assert_select 'lexxy-editor[preset=note]', count: 1
    assert_select '.bullets-form--type-pill', count: 0
    assert_select 'a.bullets-form--back'
    assert_match 'Expanded content', response.body
  end

  test 'edit task uses inline preset without type pill' do
    task = create_bullet!(@user, bulletable: Task.new, body: '<p>Do it</p>')

    get edit_bullet_path(task)

    assert_response :success
    assert_select 'lexxy-editor[preset=inline]', count: 1
    assert_select '.bullets-form--type-pill', count: 0
  end

  test 'update changes body but ignores bulletable_type change' do
    task = create_bullet!(@user, bulletable: Task.new, body: '<p>Old</p>')

    patch bullet_path(task),
          params: {
            bullet: {
              bulletable_type: 'Note',
              body: '<p>New text</p>', bulletable_attributes: { id: task.bulletable_id }
            }
          }

    assert_redirected_to bullet_path(task)
    task.reload
    assert_equal 'Task', task.bulletable_type
    assert_equal 'New text', task.body_as_text
  end

  test 'create requires bullet type' do
    post bullets_path, params: { bullet: { body: 'No type' } }

    assert_response :bad_request
  end

  test 'create allows blank body (becomes untitled)' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               body: '',
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create redirects with alert when invalid' do
    assert_no_difference -> { @user.bullets.count } do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Voice',
               body: '',
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }
    end

    assert_redirected_to daylog_path
    assert flash[:alert].present?
  end

  test 'new bullet path is removed' do
    get '/bullets/new'

    assert_response :not_found
  end

  test 'html create from a collection redirects to the bullet show' do
    collection = create_collection!(@user, name: 'Inbox')

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               body: 'Collection task',
               bucket_id: collection.bucket.id
             }
           }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create with non-Note type ignores stale bulletable_attributes' do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               body: 'Stale mood', bulletable_attributes: { mood: 'inspired' },
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           }

    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Task', bullet.bulletable_type
    assert_not bullet.bulletable.respond_to?(:mood)
  end

  test 'edit and update voice caption' do
    blob = create_blob!(filename: 'voice.webm', content_type: 'audio/webm')
    bullet = create_bullet!(@user,
      bulletable_type: 'Voice',
      body: 'Voice caption', bulletable_attributes: { recording: blob.signed_id, duration_seconds: 5 }
    )

    get edit_bullet_path(bullet)

    assert_response :success
    assert_select 'lexxy-editor[preset=inline]'

    patch bullet_path(bullet),
          params: { bullet: { body: '<p>Changed</p>', bulletable_attributes: { id: bullet.bulletable_id } } }

    assert_redirected_to bullet_path(bullet)
    assert_equal 'Changed', bullet.reload.body_as_text
  end

  test 'create json returns the bullet' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Task',
               body: '<p>API task</p>',
               pops_on: Date.current.iso8601,
               bucket_id: @daylog.id
             }
           },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'Task', body['bulletable_type']
    assert_equal 'API task', body['body']
    assert_equal false, body['completed']
    assert_equal bullet_url(Bullet.find(body['id'])), body['url']
    assert_equal bullet_url(Bullet.find(body['id'])), response.headers['Location']
  end

  test 'create json returns validation errors' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Voice',
             body: 'No recording',
             bucket_id: @daylog.id,
             pops_on: Date.current.iso8601
           }
         },
         as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body['recording'].present?
  end

  test 'create json without bulletable type returns bad request' do
    post bullets_path,
         params: {
           bullet: {
             body: 'Nope',
             bucket_id: @daylog.id,
             pops_on: Date.current.iso8601
           }
         },
         as: :json

    assert_response :bad_request
  end

  test 'bearer session code authenticates create json' do
    sign_out
    @user.update!(onboarded: true)
    auth = request_login_code_json(@user.email_address)
    confirm_login_code_json(
      code: auth[:code],
      pending_authentication_code: auth[:pending_authentication_code]
    )
    session_code = response.parsed_body['session_code']
    cookies.delete('session_id')

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             body: '<p>Bearer note</p>',
             pops_on: Date.current.iso8601,
             bucket_id: ensure_daylog!(@user).id
           }
         },
         headers: { 'Authorization' => "Bearer #{session_code}" },
         as: :json

    assert_response :created
    assert_equal 'Bearer note', response.parsed_body['body']
  end

  test 'expired bearer session code is rejected' do
    sign_out
    session_record = @user.sessions.create!
    session_code = Rails.application.message_verifier(:session_code).generate(
      session_record.id,
      expires_in: Authentication::SESSION_CODE_EXPIRY
    )

    travel Authentication::SESSION_CODE_EXPIRY + 1.minute do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Note',
               body: '<p>Too late</p>',
               pops_on: Date.current.iso8601,
               bucket_id: ensure_daylog!(@user).id
             }
           },
           headers: { 'Authorization' => "Bearer #{session_code}" },
           as: :json

      assert_response :unauthorized
    end
  end

  test 'composer create appends into monthlylog dated container from Turbo-Frame' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month
    composer = "date_#{day.iso8601}_bullets_composer"
    container = dom_id(monthlylog.bucket, day)

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: '<p>Month task</p>',
             pops_on: day.iso8601,
             bucket_id: monthlylog.bucket.id
           }
         },
         headers: { 'Turbo-Frame' => composer },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'Month task', response.body
  end

  test 'composer create appends into monthlylog unplanned container' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    composer = 'monthlylog_bullets_unplanned_composer'
    container = dom_id(monthlylog.bucket, nil)

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             body: '<p>Month note</p>',
             bucket_id: monthlylog.bucket.id
           }
         },
         headers: { 'Turbo-Frame' => composer },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'Month note', response.body
  end

  test 'composer create appends into future unplanned container' do
    future = ensure_future!(@user)
    composer = 'future_bullets_unplanned_composer'
    container = dom_id(future.bucket, nil)

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: '<p>Someday task</p>',
             bucket_id: future.bucket.id
           }
         },
         headers: { 'Turbo-Frame' => composer },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{container}"), response.body
    assert_match 'Someday task', response.body
    assert_match 'data-controller="bullet-drag"', response.body
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
