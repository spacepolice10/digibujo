# frozen_string_literal: true

require "test_helper"

class BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = @user.bullets.create!(bulletable: Task.create!, content: "Original")
  end

  test "update turbo stream replaces bullet only" do
    assert_difference -> { BulletActivity.count }, 1 do
      patch bullet_path(@bullet),
            params: { bullet: { content: "Updated" } },
            as: :turbo_stream
    end

    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_no_match(/turbo-stream action="after"/, response.body)
    assert_equal "Updated", @bullet.reload.content.to_plain_text
    assert_equal 'updated', BulletActivity.order(:created_at).last.action
  end

  test "create turbo stream appends bullet and resets editor frame" do
    collection = create_collection!(@user, name: "Fresh collection")

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: "Task",
             content: "Fresh task",
             pops_on: Date.current.iso8601,
             bucket_id: collection.bucket.id
           }
         },
         as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream action="append"/, response.body)
    assert_match(/turbo-stream action="update" target="new_bullet_form"/, response.body)
    assert_match %r{bulletable_type=Task}, response.body
    assert_match %r{bulletable_type=Note}, response.body
    assert_match %r{bulletable_type=Event}, response.body
    assert_match %r{bucket_id=#{collection.bucket.id}}, response.body
    assert_match %r{pops_on=#{Date.current.iso8601}}, response.body
  end

  test "create tags bullet from project attachment in content" do
    project = create_project!(@user, name: "Tagged")
    content = ActionText::Content.new("").append_attachables(project).to_html

    post bullets_path,
         params: {
           bullet: {
             bulletable_type: "Task",
             content: content,
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    assert_response :success
    bullet = @user.bullets.order(:created_at).last
    assert_not_equal @bullet, bullet
    assert_includes bullet.projects, project
  end

  test "show renders action text file attachments" do
    blob = create_blob!(filename: "reference.txt", content_type: "text/plain")
    @bullet.content.body = @bullet.content.body.append_attachables(blob)
    @bullet.save!

    get bullet_path(@bullet)

    assert_response :success
    assert_select ".attachment.attachment--file.attachment--inline", count: 1
    assert_select "a.attachment--name", text: "reference.txt"
  end

  test "show renders action text preview attachments inline" do
    blob = create_blob!(
      filename: "photo.png",
      content_type: "image/png",
      io: StringIO.new(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="))
    )
    @bullet.content.body = @bullet.content.body.append_attachables(blob)
    @bullet.save!

    get bullet_path(@bullet)

    assert_response :success
    assert_select "span.attachment.attachment--preview.attachment--inline", count: 1
    assert_select "img.attachment--preview-image", count: 1
  end

  test "create turbo stream renders validation errors in toasts" do
    post bullets_path,
         params: {
           bullet: { bulletable_type: "Task", content: "" }
         },
         as: :turbo_stream

    assert_response :success
    assert_select 'turbo-stream[action="update"][target="toasts"]'
    assert_select ".toasts--errmsg", text: /Content can't be blank/
    assert_select ".form-errmsg", 0
  end

  private

  def create_blob!(filename:, content_type:, io: StringIO.new("file contents"))
    ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: filename,
      content_type: content_type
    )
  end
end
