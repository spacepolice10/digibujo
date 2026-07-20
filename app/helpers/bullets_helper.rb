# frozen_string_literal: true

module BulletsHelper
  # Bullet#to_partial_path points at the type row (tasks/task, …). Pass the
  # Bullet explicitly as :bullet — Rails' default local would be :task/:note/…
  def render_bullet(bullet, **options)
    render partial: bullet.to_partial_path, locals: { bullet: bullet, **options }
  end
end
