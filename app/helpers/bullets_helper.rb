# frozen_string_literal: true

module BulletsHelper
  def render_bullet(bullet, **locals)
    local = bullet.bulletable.model_name.element.to_sym
    render(
      partial: "/#{bullet.bulletable.to_partial_path}",
      locals: { local => bullet, **locals }
    )
  end
end
