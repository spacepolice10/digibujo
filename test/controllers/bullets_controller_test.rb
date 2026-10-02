# frozen_string_literal: true

require 'test_helper'

class BulletsControllerTest < ActionDispatch::IntegrationTest
  PIXEL_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = create_bullet!(@user, body: 'Original')
  end

  test 'index does not list another user bullets' do
    private_bullet = create_bullet!(users(:two), body: 'Private bullet')

    get bullets_path

    assert_response :success
    assert_no_match private_bullet.name, response.body
  end

  test 'index returns not found for unknown collection filter' do
    get bullets_path(collection: 'missing')

    assert_response :not_found
  end

  test 'update turbo stream replaces bullet only' do
    assert_no_difference -> { Activity.count } do
      patch bullet_path(@bullet),
            params: { bullet: { body: 'Updated' } },
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
           params: { bullet: { body: 'Fresh text', pops_on: Date.current.iso8601 } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create defaults to today and stays on the timeline' do
    post bullets_path, params: { bullet: { body: 'Someday' } }

    bullet = @user.bullets.order(:created_at).last
    assert_equal Date.current, bullet.pops_on
    assert_empty bullet.collections
  end

  test 'turbo stream create appends the row to today section' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { body: 'Stream text', pops_on: Date.current.iso8601 } },
           headers: { 'Turbo-Frame' => 'timeline_composer' },
           as: :turbo_stream
    end

    assert_response :success
    assert_match %(turbo-stream action="append" target="timeline_section_today"), response.body
    assert_match 'Stream text', response.body
  end

  test 'turbo stream create for a future day does not touch the timeline' do
    post bullets_path,
         params: { bullet: { body: 'Later', pops_on: 3.days.from_now.to_date.iso8601 } },
         as: :turbo_stream

    assert_response :success
    assert_no_match 'timeline_section_today', response.body
  end

  test 'composer create on a collection appends into the collection list' do
    collection = create_collection!(@user, name: 'Inbox')
    composer = ActionView::RecordIdentifier.dom_id(collection, :bullets_composer)

    post bullets_path,
         params: { bullet: { body: '<p>Fresh today</p>', collection_id: collection.id } },
         headers: { 'Turbo-Frame' => composer },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="#{dom_id(collection)}"), response.body
    assert_match 'Fresh today', response.body
    assert_includes @user.bullets.order(:created_at).last.collections, collection
  end

  test 'create persists rich content in body' do
    post bullets_path, params: { bullet: { body: '<h1>Long detail</h1>' } }

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

  test 'edit path is removed' do
    get "/bullets/#{@bullet.id}/edit"

    assert_response :not_found
  end

  test 'update changes body' do
    bullet = create_bullet!(@user, body: '<p>Old</p>')

    patch bullet_path(bullet), params: { bullet: { body: '<p>New text</p>' } }

    assert_redirected_to bullet_path(bullet)
    assert_equal 'New text', bullet.reload.body_as_text
  end

  test 'create redirects with alert when the bullet is empty' do
    assert_no_difference -> { @user.bullets.count } do
      post bullets_path, params: { bullet: { body: '' } }
    end

    assert_redirected_to bullets_path
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
           params: { bullet: { body: 'Collection text', collection_id: collection.id } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_includes bullet.collections, collection
    assert_redirected_to bullet_path(bullet)
  end

  test 'create stores an uploaded file as a file bullet' do
    file = Rack::Test::UploadedFile.new(StringIO.new(PIXEL_PNG), 'image/png', original_filename: 'pixel.png')

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path, params: { bullet: { file: file } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert bullet.file.attached?
    assert_equal 'pixel.png', bullet.file.filename.to_s
    assert_empty bullet.body_as_text
    assert_equal 'pixel.png', bullet.name
  end

  test 'create rejects a bullet without content' do
    assert_no_difference -> { @user.bullets.count } do
      post bullets_path, params: { bullet: { body: '' } }, as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body['base'].present?
  end

  test 'create renders the file row in the timeline stream' do
    file = Rack::Test::UploadedFile.new(StringIO.new(PIXEL_PNG), 'image/png', original_filename: 'pixel.png')

    post bullets_path,
         params: { bullet: { file: file } },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="append" target="timeline_section_today"), response.body
    assert_match 'attachment--image', response.body
  end

  test 'show renders a file bullet' do
    bullet = create_file_bullet!(@user, filename: 'notes.txt')

    get bullet_path(bullet)

    assert_response :success
    assert_match 'notes.txt', response.body
  end

  test 'create json includes file details' do
    file = Rack::Test::UploadedFile.new(StringIO.new(PIXEL_PNG), 'image/png', original_filename: 'pixel.png')

    post bullets_path,
         params: { bullet: { file: file } },
         headers: { 'Accept' => 'application/json' }

    assert_response :created
    assert_equal 'pixel.png', response.parsed_body['filename']
    assert_equal 'image/png', response.parsed_body['content_type']
  end

  test 'create json returns the bullet' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { body: '<p>API text</p>', pops_on: Date.current.iso8601 } },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'API text', body['body']
    assert_equal false, body['done']
    assert_equal bullet_url(Bullet.find(body['id'])), body['url']
    assert_equal bullet_url(Bullet.find(body['id'])), response.headers['Location']
  end

  test 'create rejects a file and a body together' do
    file = Rack::Test::UploadedFile.new(StringIO.new(PIXEL_PNG), 'image/png', original_filename: 'pixel.png')

    assert_no_difference -> { @user.bullets.count } do
      post bullets_path, params: { bullet: { body: 'Both', file: file } }
    end

    assert_redirected_to bullets_path
    assert flash[:alert].present?
  end

  test 'create json rejects a non-upload file value' do
    post bullets_path,
         params: { bullet: { body: 'Both', file: 'not-an-upload' } },
         as: :json

    assert_response :unprocessable_entity
  end

  test 'create json rejects an empty bullet' do
    post bullets_path, params: { bullet: { body: '' } }, as: :json

    assert_response :unprocessable_entity
  end

  test 'create json ignores a retired bulletable_type' do
    post bullets_path, params: { bullet: { bulletable_type: 'Memo', body: 'Nope' } }, as: :json

    assert_response :created
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
         params: { bullet: { body: '<p>Bearer text</p>' } },
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
           params: { bullet: { body: '<p>Too late</p>' } },
           headers: { 'Authorization' => "Bearer #{session_code}" },
           as: :json

      assert_response :unauthorized
    end
  end

  private
end
