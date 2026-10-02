# frozen_string_literal: true

# Query-param filter for the Daylog feed: optional collection tag and pops_on range.
class Bullet::Filter
  class Error < StandardError; end

  attr_reader :user, :today, :collection, :from, :to

  def self.from_params(params, user:, today: Date.current)
    new(params, user: user, today: today)
  end

  def initialize(params, user:, today: Date.current)
    @user = user
    @today = today.to_date
    @collection = resolve_collection(params[:collection])
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    raise Error if @from && @to && @from > @to
  end

  def empty?
    collection.nil? && from.nil? && to.nil?
  end

  def label
    return collection.name if collection
    return 'Upcoming' if upcoming_only?

    'Daylog'
  end

  def upcoming_only?
    from == today + 1 && to.nil? && collection.nil?
  end

  def to_params
    {}.tap do |params|
      params[:collection] = collection.name if collection
      params[:from] = from.iso8601 if from
      params[:to] = to.iso8601 if to
    end
  end

  def includes_today?
    pops_on_range.cover?(today)
  end

  def composer_pops_on
    return today if includes_today?
    return from if from

    to || today
  end

  def apply(relation)
    relation = apply_date(relation)
    relation = relation.tagged_with(collection) if collection
    relation
  end

  private

  def resolve_collection(name)
    return if name.blank?

    user.collections.active.find_by(name: name.to_s.strip.downcase) || raise(Error)
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise Error
  end

  def apply_date(relation)
    if from.nil? && to.nil?
      relation.due(today)
    elsif from && to
      relation.where(pops_on: from..to)
    elsif from
      relation.where(pops_on: from..)
    else
      relation.where(pops_on: ..to)
    end
  end

  def pops_on_range
    if from.nil? && to.nil?
      ..today
    elsif from && to
      from..to
    elsif from
      from..Date.new(9999, 12, 31)
    else
      Date.new(1, 1, 1)..to
    end
  end
end
