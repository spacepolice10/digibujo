# frozen_string_literal: true

class RecurrenciesController < ApplicationController
  before_action :set_recurrency, only: %i[show edit update destroy]

  def show
    @tracker = RecurrencyTracker.new(user: Current.user, from: Date.current - 89.days, to: Date.current)
    @heatmap_days = (Date.current - 89.days)..Date.current
  end

  def new
    @recurrency = Recurrency.new(schedule: Recurrency::DEFAULT_SCHEDULE.dup)
  end

  def create
    @recurrency = Current.user.recurrencies.build(recurrency_attributes)
    if @recurrency.save
      redirect_to home_path, notice: 'Recurrency created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @recurrency.update(recurrency_attributes)
      redirect_to recurrency_path(@recurrency), notice: 'Recurrency updated'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @recurrency.destroy
      redirect_to home_path, notice: 'Recurrency deleted'
    else
      redirect_to recurrency_path(@recurrency), alert: 'Cannot delete — remove completions first'
    end
  end

  private

  def set_recurrency
    @recurrency = Current.user.recurrencies.find(params[:id])
  end

  def recurrency_attributes
    permitted = params.require(:recurrency).permit(
      :name, :colour, :icon, schedule_days: []
    )
    attrs = {
      name: permitted[:name],
      schedule: {
        'days' => Array(permitted[:schedule_days]).reject(&:blank?).map(&:to_i).uniq.sort
      }
    }
    attrs[:colour] = permitted[:colour].presence if permitted.key?(:colour)
    attrs[:icon] = permitted[:icon].presence if permitted.key?(:icon)
    attrs
  end
end
