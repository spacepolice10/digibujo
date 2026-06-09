# frozen_string_literal: true

require "test_helper"

class Bullets::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @first = @user.bullets.create!(bulletable: Task.create!, content: "First bullet")
    @second = @user.bullets.create!(bulletable: Note.create!, content: "Second bullet")
  end

  test "show downloads html for selected bullets" do
    get export_path, params: { bullet_ids: "#{@first.id},#{@second.id}" }

    assert_response :success
    assert_includes response.media_type, "text/html"
    assert_match(/attachment; filename="digibujo-export-\d{4}-\d{2}-\d{2}\.html"/, response.headers["Content-Disposition"])
    assert_match "<!DOCTYPE html>", response.body
    assert_match "First bullet", response.body
    assert_match "Second bullet", response.body
    assert_match "Digibujo export", response.body
  end

  test "show orders bullets chronologically" do
    get export_path, params: { bullet_ids: "#{@second.id},#{@first.id}" }

    assert_response :success
    assert_operator response.body.index("First bullet"), :<, response.body.index("Second bullet")
  end

  test "show marks completed tasks as done" do
    @first.bulletable.complete!

    get export_path, params: { bullet_ids: @first.id.to_s }

    assert_response :success
    assert_match "export--bullet-body--done", response.body
    assert_match "Done", response.body
  end

  test "show returns not found without bullet ids" do
    get export_path

    assert_response :not_found
  end

  test "show returns not found for foreign bullet id" do
    foreign = users(:two).bullets.create!(bulletable: Task.create!, content: "Nope")

    get export_path, params: { bullet_ids: foreign.id.to_s }

    assert_response :not_found
  end

  test "show returns not found when more than max bulk ids" do
    ids = (1..201).to_a.join(",")

    get export_path, params: { bullet_ids: ids }

    assert_response :not_found
  end
end
