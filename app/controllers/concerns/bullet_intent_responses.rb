# frozen_string_literal: true

# Turbo + HTML fallbacks for bullet intent actions (collect, schedule) from the timeline,
# pinned list, and elsewhere. Optional +display_on+ (ISO date) matches +bullets#index+ day scope for stream replace vs remove.
module BulletIntentResponses
  extend ActiveSupport::Concern

  private

  def respond_with_bullet_intent
    respond_to do |format|
      format.turbo_stream { render turbo_stream: bullet_intent_turbo_stream }
      format.html { redirect_to bullets_path }
    end
  end

  def bullet_intent_turbo_stream
    if bullet_still_on_viewing_timeline?
      turbo_stream.replace(@bullet, partial: @bullet.to_partial_path, locals: bullet_partial_locals)
    else
      turbo_stream.remove(@bullet)
    end
  end

  def timeline_display_date
    return @timeline_display_date if defined?(@timeline_display_date)

    @timeline_display_date = parse_iso_date(params[:display_on])
  end

  def parse_iso_date(value)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def bullet_still_on_viewing_timeline?
    day = timeline_display_date
    return true if day.nil?

    @bullet.reload
    Current.user.bullets.scheduled_on_date(day).where(id: @bullet.id, archived: false).exists?
  end

  def bullet_partial_locals
    { @bullet.bulletable_type.downcase.to_sym => @bullet }
  end
end
