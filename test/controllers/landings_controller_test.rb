# frozen_string_literal: true

require 'test_helper'

class LandingsControllerTest < ActionDispatch::IntegrationTest
  test 'show is available without authentication' do
    get landing_path

    assert_response :success
    assert_select 'html[lang="en"]', count: 1
    assert_select 'link[rel="preconnect"][href="https://fonts.gstatic.com"]', count: 1
    assert_select 'link[rel="stylesheet"][href^="/assets/"]', count: 8
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="button"]', minimum: 1
    assert_select 'link[rel="stylesheet"][href*="components/search"]', count: 0
    assert_select 'script', count: 0
    assert_select 'header.landing-header .landing-menu-toggle[type="checkbox"]', count: 1
    assert_select 'header.landing-header nav[aria-label="Product"] a', count: 4

    csp = response.headers.fetch('Content-Security-Policy')
    assert_includes csp, "default-src 'none'"
    assert_includes csp, "connect-src 'self'"
    assert_includes csp, "style-src 'self' https://fonts.googleapis.com"
    assert_includes csp, "style-src-attr 'unsafe-inline'"
    assert_includes csp, "frame-ancestors 'none'"
    assert_not_includes csp, 'script-src'
  end

  test 'header markup is the same for phone user agents' do
    get landing_path
    desktop_header = css_select('header.landing-header').first.to_html

    get landing_path, headers: { 'User-Agent' => 'iPhone' }

    assert_response :success
    assert_equal desktop_header, css_select('header.landing-header').first.to_html
  end
end
