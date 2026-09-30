# frozen_string_literal: true

require 'test_helper'

class BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = create_bullet!(@user, body: 'Original')
  end

  test 'index lists active bullets newest first' do
    older = create_bullet!(@user, body: 'Older bullet', created_at: 2.days.ago)
    newer = create_bullet!(@user, body: 'Newer bullet', created_at: 1.day.ago)
    archived = create_bullet!(@user, body: 'Archived bullet')
    archived.archive!

    get bullets_path

    assert_response :success
    assert_select 'h1', text: 'Bullets'
    assert_select '#bullets-timeline'
    assert_operator response.body.index(newer.name), :<, response.body.index(older.name)
    assert_no_match archived.name, response.body
  end

  test 'index does not list another user bullets' do
    private_bullet = create_bullet!(users(:two), body: 'Private bullet')

    get bullets_path

    assert_response :success
    assert_no_match private_bullet.name, response.body
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
           params: { bullet: { bulletable_type: 'Text', body: 'Fresh text', pops_on: Date.current.iso8601 } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create defaults to today and stays on the timeline' do
    post bullets_path, params: { bullet: { bulletable_type: 'Text', body: 'Someday' } }

    bullet = @user.bullets.order(:created_at).last
    assert_equal Date.current, bullet.pops_on
    assert_nil bullet.collection_id
  end

  test 'turbo stream create appends the row to today section' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { bulletable_type: 'Text', body: 'Stream text', pops_on: Date.current.iso8601 } },
           headers: { 'Turbo-Frame' => 'timeline_composer' },
           as: :turbo_stream
    end

    assert_response :success
    assert_match %(turbo-stream action="append" target="timeline_section_today"), response.body
    assert_match 'Stream text', response.body
  end

  test 'turbo stream create for a future day does not touch the timeline' do
    post bullets_path,
         params: { bullet: { bulletable_type: 'Text', body: 'Later', pops_on: 3.days.from_now.to_date.iso8601 } },
         as: :turbo_stream

    assert_response :success
    assert_no_match 'timeline_section_today', response.body
  end

  test 'composer create on a collection appends into the collection list' do
    collection = create_collection!(@user, name: 'Inbox')
    composer = ActionView::RecordIdentifier.dom_id(collection, :bullets_composer)

    post bullets_path,
         params: { bullet: { bulletable_type: 'Text', body: '<p>Fresh today</p>', collection_id: collection.id } },
         headers: { 'Turbo-Frame' => composer },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{dom_id(collection)}"), response.body
    assert_match 'Fresh today', response.body
    assert_equal collection, @user.bullets.order(:created_at).last.collection
  end

  test 'composer create reports validation errors as a toast' do
    post bullets_path,
         params: { bullet: { bulletable_type: 'Memo', body: 'No recording attached' } },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match %(turbo-stream action="update" target="toasts"), response.body
    assert_match 'Recording', response.body
  end

  test 'create tags bullet from project attachment in body' do
    project = create_project!(@user, name: 'Tagged')
    body_html = ActionText::Content.new('').append_attachables(project).to_html

    post bullets_path, params: { bullet: { bulletable_type: 'Text', body: body_html } }

    bullet = @user.bullets.order(:created_at).last
    assert_not_equal @bullet, bullet
    assert_includes bullet.projects, project
  end

  test 'create persists rich content in body' do
    post bullets_path, params: { bullet: { bulletable_type: 'Text', body: '<h1>Long detail</h1>' } }

    bullet = @user.bullets.order(:created_at).last
    assert_match 'Long detail', bullet.body.to_plain_text
    assert_includes bullet.body.body_before_type_cast.to_s, '<h1'
  end

  test 'show renders body' do
    bullet = create_bullet!(@user, body: '<p>Expanded content</p>')

    get bullet_path(bullet)

    assert_response :success
    assert_match 'Expanded content', response.body
  end

  test 'show renders unarchive for archived bullet' do
    bullet = create_bullet!(@user, body: 'Archived text')
    bullet.archive!

    get bullet_path(bullet)

    assert_response :success
    assert_select 'form[action=?][method=post]', archive_path do
      assert_select 'input[name=_method][value=delete]'
      assert_select 'button', text: /Unarchive/
    end
  end

  test 'edit renders the body editor with saved content' do
    bullet = create_bullet!(@user, body: '<p>Expanded content</p>')

    get edit_bullet_path(bullet)

    assert_response :success
    assert_select 'lexxy-editor', count: 1
    assert_match 'Expanded content', response.body
  end

  test 'update changes body but ignores bulletable_type change' do
    bullet = create_bullet!(@user, body: '<p>Old</p>')

    patch bullet_path(bullet),
          params: {
            bullet: {
              bulletable_type: 'Memo',
              body: '<p>New text</p>', bulletable_attributes: { id: bullet.bulletable_id }
            }
          }

    assert_redirected_to bullet_path(bullet)
    bullet.reload
    assert_equal 'Text', bullet.bulletable_type
    assert_equal 'New text', bullet.body_as_text
  end

  test 'create requires bullet type' do
    post bullets_path, params: { bullet: { body: 'No type' } }

    assert_response :bad_request
  end

  test 'create rejects retired bullet types' do
    %w[Task Note Event Voice].each do |type|
      post bullets_path, params: { bullet: { bulletable_type: type, body: 'Old kind' } }

      assert_response :bad_request
    end
  end

  test 'create allows blank body (becomes untitled)' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path, params: { bullet: { bulletable_type: 'Text', body: '' } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create redirects with alert when invalid' do
    assert_no_difference -> { @user.bullets.count } do
      post bullets_path, params: { bullet: { bulletable_type: 'Memo', body: '' } }
    end

    assert_redirected_to timeline_path
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
           params: { bullet: { bulletable_type: 'Text', body: 'Collection text', collection_id: collection.id } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_equal collection, bullet.collection
    assert_redirected_to bullet_path(bullet)
  end

  test 'create ignores stale bulletable_attributes on text' do
    post bullets_path,
         params: { bullet: { bulletable_type: 'Text', body: 'Stale mood', bulletable_attributes: { mood: 'inspired' } } }

    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Text', bullet.bulletable_type
    assert_not bullet.bulletable.respond_to?(:mood)
  end

  test 'edit and update memo caption' do
    blob = create_blob!(filename: 'voice.webm', content_type: 'audio/webm')
    bullet = create_bullet!(@user,
                            bulletable_type: 'Memo',
                            bulletable: nil,
                            body: 'Memo caption',
                            bulletable_attributes: { recording: blob.signed_id, duration_seconds: 5 })

    get edit_bullet_path(bullet)

    assert_response :success
    assert_select 'lexxy-editor'

    patch bullet_path(bullet),
          params: { bullet: { body: '<p>Changed</p>', bulletable_attributes: { id: bullet.bulletable_id } } }

    assert_redirected_to bullet_path(bullet)
    assert_equal 'Changed', bullet.reload.body_as_text
  end

  test 'create json returns the bullet' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { bulletable_type: 'Text', body: '<p>API text</p>', pops_on: Date.current.iso8601 } },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'Text', body['bulletable_type']
    assert_equal 'API text', body['body']
    assert_equal false, body['done']
    assert_equal bullet_url(Bullet.find(body['id'])), body['url']
    assert_equal bullet_url(Bullet.find(body['id'])), response.headers['Location']
  end

  test 'create json returns validation errors' do
    post bullets_path,
         params: { bullet: { bulletable_type: 'Memo', body: 'No recording' } },
         as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body['recording'].present?
  end

  test 'create json without bulletable type returns bad request' do
    post bullets_path, params: { bullet: { body: 'Nope' } }, as: :json

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
         params: { bullet: { bulletable_type: 'Text', body: '<p>Bearer text</p>' } },
         headers: { 'Authorization' => "Bearer #{session_code}" },
         as: :json

    assert_response :created
    assert_equal 'Bearer text', response.parsed_body['body']
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
           params: { bullet: { bulletable_type: 'Text', body: '<p>Too late</p>' } },
           headers: { 'Authorization' => "Bearer #{session_code}" },
           as: :json

      assert_response :unauthorized
    end
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
