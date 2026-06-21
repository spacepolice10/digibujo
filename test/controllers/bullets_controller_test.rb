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

  test 'create turbo stream inserts bullet before composer' do
    collection = create_collection!(@user, name: 'Fresh collection')

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: 'Fresh task',
             pops_on: Date.current.iso8601,
             bucket_id: collection.bucket.id,
             composer_id: 'bullet_composer'
           }
         },
         as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream action="before" target="bullet_composer"/, response.body)
    assert_no_match(/turbo-stream action="update" target="bullet_composer"/, response.body)
    assert_no_match(/Add bullet/, response.body)
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

  test 'create attaches direct uploads' do
    blob = create_blob!(filename: 'reference.txt', content_type: 'text/plain')

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: 'With file',
             attachments: [blob.signed_id],
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    bullet = @user.bullets.order(:created_at).last
    assert_equal 1, bullet.attachments.count
    assert_equal 'reference.txt', bullet.attachments.first.filename.to_s
  end

  test 'create persists rich_body from expand dialog' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Note',
             body: 'Short line',
             rich_body: '<p>Long detail</p>',
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    bullet = @user.bullets.order(:created_at).last
    assert bullet.rich_body?
    assert_match 'Long detail', bullet.rich_body.to_plain_text
  end

  test 'rich_body with project attachment does not tag project' do
    project = create_project!(@user, name: 'Hidden')
    rich_body = ActionText::Content.new('Detail').append_attachables(project).to_html

    patch bullet_path(@bullet),
          params: { bullet: { rich_body: rich_body } },
          as: :turbo_stream

    @bullet.reload
    assert_empty @bullet.projects
    assert_empty @bullet.rich_body.body.attachables.grep(Project)
  end

  test 'create ignores blank rich_body' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: 'Only body',
             rich_body: '',
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    bullet = @user.bullets.order(:created_at).last
    assert_not bullet.rich_body?
  end

  test 'show renders direct attachments' do
    blob = create_blob!(filename: 'reference.txt', content_type: 'text/plain')
    @bullet.attachments.attach(blob)

    get bullet_path(@bullet)

    assert_response :success
    assert_select '.attachment--gallery', count: 1
    assert_select 'a.attachment--name', text: 'reference.txt'
  end

  test 'show renders rich_body section' do
    @bullet.update!(rich_body: '<p>Expanded content</p>')

    get bullet_path(@bullet)

    assert_response :success
    assert_select '.bullet--rich-body', count: 1
    assert_match 'Expanded content', response.body
  end

  test 'edit renders rich_body preview in composer' do
    @bullet.update!(rich_body: '<p>Expanded content</p>')

    get edit_bullet_path(@bullet)

    assert_response :success
    assert_select '.bullet-form-rich-body-preview', count: 1
    assert_select '.bullet-form-rich-body-preview[hidden]', count: 0
    assert_select '.bullet-form-rich-body-preview-content', text: /Expanded content/
  end

  test 'create with invalid body shows validation toast' do
    post bullets_path,
         params: {
           bullet: { bulletable_type: 'Task', body: '', composer_id: 'bullet_composer' }
         },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match %(turbo-stream action="update" target="toasts"), response.body
    assert_match "Body can&#39;t be blank", response.body
    assert_no_match 'form.bullet-form', response.body
  end

  test 'new composer renders inline editor with rail layout' do
    get new_bullet_path

    assert_response :success
    assert_select 'form.bullet-form'
    assert_select 'lexxy-editor[preset=inline]'
    assert_select '.bullet-form-rail'
    assert_select '.bullet-form-rail-actions'
    assert_select 'select.select-menu.bullet-form-actions-select.form-select', aria: { label: 'Composer options' }
    assert_select 'select.bullet-form-actions-select option[value=?]', 'attachment'
    assert_select 'select.bullet-form-actions-select option[value=?]', 'expand'
    assert_select 'select.select-menu.bullet-form-type-select.form-select', aria: { label: 'Bullet type' }
    assert_select 'select.bullet-form-type-select option[value=?]', 'Task', text: /Task/
    assert_select 'select.bullet-form-type-select option[value=?]', 'Note', text: /Note/
    assert_select 'select.bullet-form-type-select option[value=?]', 'Event', text: /Event/
    assert_select 'select.bullet-form-type-select option[value=?]', 'Title', text: /Title/
    assert_select '.bullet-form-note-options .bullet-form-note-flag', count: 2
    assert_select '.bullet-form-rich-body-preview[hidden]', count: 1
    assert_select '.bullet-form-rail-actions .bullet-form-rail-submit button[type=submit]'
    assert_select 'input[name=?][type=checkbox].utilities--sr-only', 'bullet[indented]'
    assert_select '.bullet-form-footer', count: 0
  end

  test 'create Title bullet with body' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Title',
             body: 'My Heading',
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    assert_response :success
    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Title', bullet.bulletable_type
    assert_equal 'My Heading', bullet.name
    assert bullet.body.present?
  end

  test 'update indented flag' do
    patch bullet_path(@bullet),
          params: { bullet: { indented: true } },
          as: :turbo_stream

    assert_response :success
    assert @bullet.reload.indented
  end

  test 'create indented bullet' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: 'Indented task',
             indented: true,
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    assert_response :success
    bullet = @user.bullets.order(:created_at).last
    assert bullet.indented
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
