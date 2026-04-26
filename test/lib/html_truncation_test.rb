# frozen_string_literal: true

require "test_helper"

class HtmlTruncationTest < ActiveSupport::TestCase
  test "leaves short HTML alone" do
    html = "<p>Hello</p>"
    assert_equal html, HtmlTruncation.truncate_html(html, 20)
  end

  test "splits text in the middle" do
    result = HtmlTruncation.truncate_html("<p>Hello</p>", 2)
    assert_includes result, "He"
    assert_includes result, "…"
    assert_not_includes result, "llo"
  end

  test "keeps tags that enclose the kept part" do
    result = HtmlTruncation.truncate_html("<p><b>Bolded text here</b></p>", 8)
    assert_includes result, "<b>"
    assert_includes result, "Bolded t"
    assert_includes result, "…"
  end

  test "drops text after a cut in a later text node" do
    result = HtmlTruncation.truncate_html(
      "<p>First <strong>bold bit</strong> and more.</p>", 6
    )
    assert_includes result, "First"
    assert_not_includes result, "bold bit"
  end
end
