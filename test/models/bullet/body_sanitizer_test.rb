# frozen_string_literal: true

require 'test_helper'

class Bullet::BodySanitizerTest < ActiveSupport::TestCase
  def make_bullet(type, body_html)
    bullet = Bullet.new(bulletable_type: type, bulletable: type.constantize.new, user: users(:one))
    bullet.body = ActionText::Content.new(body_html) if body_html
    bullet
  end

  def apply(bullet)
    Bullet::BodySanitizer.apply(bullet)
  end

  test 'non-Note keeps project action-text attachment' do
    project = Project.create!(user: users(:one), name: 'Ship')
    attachable_html = ActionText::Attachment.from_attachables([project]).first.to_html
    bullet = make_bullet('Task', "<p>Ship it #{attachable_html}</p>")

    apply(bullet)

    assert_empty bullet.errors[:body]
    assert_includes bullet.body.body_before_type_cast.to_s, 'action-text-attachment'
    assert_includes bullet.body.to_plain_text, 'Ship it'
  end

  test 'non-Note strips file action-text attachment' do
    file_embed = '<action-text-attachment content-type="image/png" url="http://example.com/x.png"></action-text-attachment>'
    bullet = make_bullet('Task', "<p>check this #{file_embed}</p>")

    apply(bullet)

    refute_includes bullet.body.body_before_type_cast.to_s, 'action-text-attachment'
    assert_includes bullet.body.to_plain_text, 'check this'
  end

  test 'non-Note unwraps block nodes to inner text' do
    bullet = make_bullet('Task', '<h1>Title</h1><pre>code</pre><blockquote>quote</blockquote>')

    apply(bullet)

    assert_equal 'Titlecodequote', bullet.body.to_plain_text.strip
  end

  test 'non-Note collapses to a single paragraph' do
    bullet = make_bullet('Task', '<p>a</p><p>b</p><p>c</p>')

    apply(bullet)

    assert_equal 'abc', bullet.body.to_plain_text.strip
  end

  test 'non-Note keeps inline strong em a' do
    bullet = make_bullet('Task', "<p>go <strong>now</strong> <em>please</em> <a href='/x'>here</a></p>")

    apply(bullet)

    html = bullet.body.body_before_type_cast.to_s
    assert_includes html, '<strong>now</strong>'
    assert_includes html, '<em>please</em>'
    assert_includes html, '<a'
  end

  test 'Note is pass-through (keeps file embed and block nodes)' do
    file_embed = '<action-text-attachment content-type="image/png" url="http://example.com/x.png"></action-text-attachment>'
    bullet = make_bullet('Note', "<h1>Title</h1><pre>code</pre><p>img: #{file_embed}</p>")

    apply(bullet)

    assert_empty bullet.errors[:body]
    html = bullet.body.body_before_type_cast.to_s
    assert_includes html, '<h1'
    assert_includes html, '<pre'
    assert_includes html, 'action-text-attachment'
  end

  test 'Task under 280 is valid' do
    bullet = make_bullet('Task', "<p>#{'a' * 280}</p>")
    apply(bullet)
    assert_empty bullet.errors[:body]
  end

  test 'Task over 280 is invalid' do
    bullet = make_bullet('Task', "<p>#{'a' * 281}</p>")
    apply(bullet)
    assert_includes bullet.errors[:body].join, '280'
  end

  test 'Note under 5000 is valid' do
    bullet = make_bullet('Note', "<p>#{'a' * 5000}</p>")
    apply(bullet)
    assert_empty bullet.errors[:body]
  end

  test 'Note over 5000 is invalid' do
    bullet = make_bullet('Note', "<p>#{'a' * 5001}</p>")
    apply(bullet)
    assert_includes bullet.errors[:body].join, '5000'
  end

  test 'Task with text is valid' do
    bullet = make_bullet('Task', '<p>ship it</p>')
    apply(bullet)
    assert_empty bullet.errors[:body]
  end

  test 'Task blank is invalid' do
    bullet = make_bullet('Task', '')
    apply(bullet)
    assert_includes bullet.errors[:body].join, 'blank'
  end

  test 'Task with only whitespace is invalid' do
    bullet = make_bullet('Task', '<p>   </p>')
    apply(bullet)
    assert_includes bullet.errors[:body].join, 'blank'
  end

  test 'Note with only file embed is valid' do
    embed = '<action-text-attachment content-type="application/pdf" ' \
            'url="http://example.com/x.pdf" sgid="dummy"></action-text-attachment>'
    bullet = make_bullet('Note', embed)
    apply(bullet)
    assert_empty bullet.errors[:body], bullet.errors.full_messages.join(', ')
  end
end
