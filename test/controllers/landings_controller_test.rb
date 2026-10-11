# frozen_string_literal: true

require 'test_helper'

class LandingsControllerTest < ActionDispatch::IntegrationTest
  test 'landing page is available without authentication' do
    get landing_path

    assert_response :success
    assert_select 'html[lang="en"]', count: 1
    assert_select 'link[rel="preconnect"][href="https://fonts.gstatic.com"]', count: 1
    assert_select 'link[rel="stylesheet"][href^="/assets/"]', count: 10
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="typography"]', count: 1
    assert_select 'h1.branding-heading', text: 'dotted', count: 1
    assert_select 'link[rel="stylesheet"][href*="/card-"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="/pressable-"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="domain/search"]', count: 0
    assert_select 'script', count: 0
    assert_select 'body > header.landing-header .landing-menu-toggle[type="checkbox"]', count: 1
    assert_select 'header.landing-header nav[aria-label="Product"] a', count: 4
    assert_select 'header.landing-header nav[aria-label="Product"] a[href=?]', once_path, text: /ONCE/

    csp = response.headers.fetch('Content-Security-Policy')
    assert_includes csp, "default-src 'none'"
    assert_includes csp, "connect-src 'self'"
    assert_includes csp, "style-src 'self' https://fonts.googleapis.com"
    assert_includes csp, "style-src-attr 'unsafe-inline'"
    assert_includes csp, "frame-ancestors 'none'"
    assert_not_includes csp, 'script-src'
  end

  test 'features page uses the landing layout and security policy' do
    get features_path

    assert_response :success
    assert_match 'Rapid logging', response.body
    assert_no_match 'Email code', response.body
    assert_select 'html[lang="en"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'body > header.landing-header', count: 1
    assert_select 'main[data-page="features"] > header.landing-page-heading h1', text: 'Features'
    assert_select 'header.landing-header a[href=?]', landing_path
    assert_select 'a[href=?]', new_authentication_path, text: /Create your own/
    assert_includes response.headers.fetch('Content-Security-Policy'), "default-src 'none'"
  end

  test 'support page uses the landing layout and security policy' do
    get support_path

    assert_response :success
    assert_select 'html[lang="en"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'body > main[data-page="support"]', count: 1
    assert_select 'body > header.landing-header', count: 1
    assert_select 'header.landing-header a[href=?]', landing_path
    assert_select 'a[href=?]', 'mailto:naysdemo@zohomail.com'
    assert_select 'a[href=?]', 'https://github.com/spacepolice10/digibujo'
    assert_includes response.headers.fetch('Content-Security-Policy'), "default-src 'none'"
  end

  test 'once guide is public and uses the landing layout' do
    get once_path

    assert_response :success
    assert_select 'html[lang="en"]', count: 1
    assert_select 'body > header.landing-header', count: 1
    assert_select 'main[data-page="once"][data-size="md"]', count: 1
    assert_select 'section.once-card h1', text: /Dotted.*ONCE-ready/, count: 1
    assert_select 'article[data-elevation="1"]', count: 3
    assert_select 'pre code', text: /once deploy ghcr\.io\/spacepolice10\/digibujo:latest/
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'script', count: 0
  end

  test 'header markup is the same for phone user agents' do
    get landing_path
    desktop_header = css_select('header.landing-header').first.to_html

    get landing_path, headers: { 'User-Agent' => 'iPhone' }

    assert_response :success
    assert_equal desktop_header, css_select('header.landing-header').first.to_html
  end

  test 'all landing pages have the same navigation header' do
    get landing_path
    landing_header = css_select('header.landing-header').first.to_html

    [features_path, support_path, once_path].each do |path|
      get path
      assert_response :success
      assert_equal landing_header, css_select('header.landing-header').first.to_html
    end
  end
end
