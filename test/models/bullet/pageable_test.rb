# frozen_string_literal: true

require 'test_helper'

class Bullet::PageableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_daylog!(@user)
  end

  test 'last_page returns the newest bullets in reading order' do
    bullets = create_bullets(5)

    page = @user.bullets.last_page(size: 3)

    assert_equal bullets.last(3).map(&:id), page.map(&:id)
  end

  test 'last_page returns everything when the day is shorter than a page' do
    bullets = create_bullets(2)

    assert_equal bullets.map(&:id), @user.bullets.last_page(size: 3).map(&:id)
  end

  test 'page_before returns the batch just older than the cursor' do
    bullets = create_bullets(6)

    page = @user.bullets.page_before(bullets[3], size: 2)

    assert_equal bullets[1..2].map(&:id), page.map(&:id)
  end

  test 'page_before is empty once the oldest bullet is the cursor' do
    bullets = create_bullets(2)

    assert_empty @user.bullets.page_before(bullets.first)
  end

  test 'page_before breaks created_at ties on id' do
    timestamp = 2.hours.ago
    bullets = Array.new(3) do |index|
      create_bullet!(@user, bulletable: Note.new(body: "Tied #{index}"), created_at: timestamp)
    end

    page = @user.bullets.page_before(bullets.last)

    assert_equal bullets.first(2).map(&:id), page.map(&:id)
  end

  private

  def create_bullets(count)
    Array.new(count) do |index|
      create_bullet!(@user, bulletable: Note.new(body: "Line #{index}"), created_at: (count - index).minutes.ago)
    end
  end
end
