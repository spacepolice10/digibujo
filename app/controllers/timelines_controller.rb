# frozen_string_literal: true

class TimelinesController < ApplicationController
  def show
    @timeline = Current.user.timeline
    @bullets = @timeline.last_page
    @more_bullets = @bullets.size == Bullet::Pageable::PAGE_SIZE
  end
end
