# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper
  include IconHelper

  test 'current futures navigation links to the covering future' do
    future = ensure_future!(users(:one))
    Current.user = users(:one)

    assert_equal future_path(future), current_futures_navigation_path
  end

  test 'current futures navigation falls back when no future covers today' do
    Current.user = users(:two)

    assert_equal current_future_path, current_futures_navigation_path
  end

  test 'back_link_to renders fallback href and navigation data' do
    html = back_link_to(home_path, class: 'button--tertiary button--sm') do
      safe_join([icon_tag('arrow-left'), ' Back'])
    end

    assert_includes html, %(href="#{home_path}")
    assert_includes html, 'class="button--tertiary button--sm"'
    assert_includes html, 'data-controller="navigation"'
    assert_match(/data-action="[^"]*click-&gt;navigation#back/, html)
    assert_includes html, 'arrow-left'
    assert_includes html, 'Back'
  end

  test 'back_link_to merges existing data controller and action' do
    html = back_link_to(
      projects_path,
      data: { controller: 'hotkey', action: 'keydown.esc@document->hotkey#click', turbo_frame: '_top' }
    ) { 'Back' }

    assert_includes html, %(href="#{projects_path}")
    assert_includes html, 'data-controller="hotkey navigation"'
    assert_match(/keydown\.esc@document-&gt;hotkey#click/, html)
    assert_match(/click-&gt;navigation#back/, html)
    assert_includes html, 'data-turbo-frame="_top"'
  end

  test 'represent_image_tag uses a resized representation' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
      )),
      filename: 'photo.png',
      content_type: 'image/png'
    )

    html = represent_image_tag(blob, variant: :preview, alt: 'photo.png', class: 'preview')

    assert_includes html, 'class="preview"'
    assert_includes html, 'alt="photo.png"'
    assert_includes html, '/representations/'
    assert_no_match(%r{/rails/active_storage/blobs/redirect/}, html)
  end

  test 'represent_image_tag reserves layout with scaled width and height' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
      )),
      filename: 'photo.png',
      content_type: 'image/png'
    )
    blob.update!(metadata: blob.metadata.merge('width' => 1600, 'height' => 900, 'analyzed' => true))

    html = represent_image_tag(blob, variant: :preview, alt: 'photo.png')

    assert_includes html, 'width="800"'
    assert_includes html, 'height="450"'
  end
end
