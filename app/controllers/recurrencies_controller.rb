# frozen_string_literal: true

class RecurrenciesController < ApplicationController
  before_action :set_recurrency, only: %i[show edit update destroy]

  def index
    @recurrencies = Current.user.recurrencies.chronological
    @tracker = RecurrencyTracker.new(
      user: Current.user,
      from: Date.current.beginning_of_month,
      to: Date.current.end_of_month
    )
  end

  def show
    @month = month_from_params
    @tracker = RecurrencyTracker.new(user: Current.user, from: @month.beginning_of_month, to: @month.end_of_month)
    @period_days = (@month.beginning_of_month..@month.end_of_month)
    @heatmap_months = heatmap_months
    @heatmap_completions = @recurrency.completions.pluck(:date).to_set
  end

  def new
    @recurrency = Recurrency.new(schedule: { "kind" => "daily" })
  end

  def create
    @recurrency = Current.user.recurrencies.build(recurrency_attributes)
    if @recurrency.save
      redirect_to recurrency_path(@recurrency), notice: "Recurrency created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @recurrency.update(recurrency_attributes)
      redirect_to recurrency_path(@recurrency), notice: "Recurrency updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @recurrency.destroy
      redirect_to recurrencies_path, notice: "Recurrency deleted"
    else
      redirect_to recurrency_path(@recurrency), alert: "Cannot delete — set an end date or remove completions first"
    end
  end

  private

  def set_recurrency
    @recurrency = Current.user.recurrencies.find(params[:id])
  end

  def month_from_params
    if params[:month].present?
      Date.strptime(params[:month], "%Y-%m")
    else
      Date.current
    end
  rescue ArgumentError
    Date.current
  end

  def heatmap_months
    12.times.map { |index| Date.current.beginning_of_month - index.months }.reverse
  end

  def recurrency_attributes
    permitted = params.require(:recurrency).permit(
      :name, :colour, :icon, :active_from, :active_to, :schedule_kind, schedule_days: []
    )
    attrs = {
      name: permitted[:name],
      active_from: permitted[:active_from].presence,
      active_to: permitted[:active_to].presence,
      schedule: schedule_from(permitted)
    }
    attrs[:colour] = permitted[:colour].presence if permitted.key?(:colour)
    attrs[:icon] = permitted[:icon].presence if permitted.key?(:icon)
    attrs
  end

  def schedule_from(permitted)
    kind = permitted[:schedule_kind].presence || "daily"
    case kind
    when "custom"
      days = Array(permitted[:schedule_days]).reject(&:blank?).map(&:to_i)
      { "kind" => "custom", "days" => days }
    else
      { "kind" => kind }
    end
  end
end
