# frozen_string_literal: true

class TrackersController < ApplicationController
  before_action :set_tracker, only: %i[show edit update destroy]

  def index
    @trackers = Current.user.trackers
  end

  def new
    @tracker = Current.user.trackers.new(schedule: Tracker::DEFAULT_SCHEDULE.dup)
  end

  def create
    @tracker = Current.user.trackers.build(tracker_attributes)
    @tracker.start_date = Date.current

    if @tracker.save
      redirect_to trackers_path, notice: 'Tracker created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @tracker = Current.user.trackers.where(id: @tracker.id).with_completions.first
    @heatmap_days = (30.days.ago.to_date..Date.current).to_a
  end

  def edit; end

  def update
    if @tracker.update(tracker_attributes)
      redirect_to tracker_path(@tracker), notice: 'Tracker updated'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tracker.destroy!
    redirect_to root_path, notice: 'Tracker deleted'
  end

  private

  def set_tracker
    @tracker = Current.user.trackers.find(params[:id])
  end

  def tracker_attributes
    permitted = params.require(:tracker).permit(
      :name, :colour, :icon, schedule_days: []
    )
    attrs = {
      name: permitted[:name],
      schedule: {
        'days' => Array(permitted[:schedule_days]).reject(&:blank?).map(&:to_i).uniq.sort.presence ||
                  Tracker::DEFAULT_SCHEDULE['days']
      }
    }
    attrs[:colour] = permitted[:colour].presence if permitted.key?(:colour)
    attrs[:icon] = permitted[:icon].presence if permitted.key?(:icon)
    attrs
  end
end
