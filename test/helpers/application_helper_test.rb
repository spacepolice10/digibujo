# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper
  include IconHelper

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
end
