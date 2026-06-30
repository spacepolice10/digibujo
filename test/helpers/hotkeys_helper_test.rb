require "test_helper"

class HotkeysHelperTest < ActionView::TestCase
  test "converts a chord to a stimulus click action" do
    assert_equal "keydown.shift+t@document->hotkey#click", hotkey_click_action("Shift+T")
  end

  test "converts multiple chords" do
    assert_equal "keydown.2@document->hotkey#click keydown.ctrl+d@document->hotkey#click keydown.meta+d@document->hotkey#click",
      hotkey_click_action("2", "Ctrl+D", "Meta+D")
  end

  test "downcases letter keys for stimulus filters" do
    assert_equal "keydown.shift+s@document->hotkey#click", hotkey_click_action("Shift+S")
  end
end
