# frozen_string_literal: true

require "test_helper"

class Person::HandleTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @person = @user.people.create!(name: "alex")
  end

  test "email requires valid format" do
    handle = @person.handles.build(kind: :email, data: "not-an-email")

    assert_not handle.valid?
    assert_includes handle.errors[:data], "is invalid"
  end

  test "handle requires platform from PLATFORMS" do
    handle = @person.handles.build(kind: :handle, platform: "instagram", data: "alex")

    assert handle.valid?
  end

  test "handle rejects unknown platform" do
    handle = @person.handles.build(kind: :handle, platform: "unknown", data: "alex")

    assert_not handle.valid?
    assert_includes handle.errors[:platform], "is not included in the list"
  end

  test "email and phone require blank platform" do
    handle = @person.handles.build(kind: :email, platform: "instagram", data: "alex@example.com")

    assert_not handle.valid?
    assert_includes handle.errors[:platform], "must be blank"
  end

  test "allows duplicate phones" do
    @person.handles.create!(kind: :phone, data: "+1 111")
    duplicate = @person.handles.build(kind: :phone, data: "+1 222")

    assert duplicate.valid?
    assert duplicate.save
  end

  test "href for email and phone" do
    email = @person.handles.create!(kind: :email, data: "Alex@Example.com")
    phone = @person.handles.create!(kind: :phone, data: "+1 555")

    assert_equal "mailto:alex@example.com", email.href
    assert_equal "tel:+1 555", phone.href
  end

  test "href for social handle with url template" do
    handle = @person.handles.create!(kind: :handle, platform: "instagram", data: "@alex")

    assert_equal "https://instagram.com/alex", handle.href
    assert_equal "Instagram: alex", handle.display_label
  end

  test "href is nil for platforms without url template" do
    handle = @person.handles.create!(kind: :handle, platform: "signal", data: "alex.42")

    assert_nil handle.href
    assert_equal "Signal: alex.42", handle.display_label
  end

  test "touching handle updates person search index" do
    @person.handles.create!(kind: :email, data: "alex@example.com")

    record = Search::Record.find_by(searchable: @person)
    assert_includes record.search_body, "alex@example.com"
  end
end
