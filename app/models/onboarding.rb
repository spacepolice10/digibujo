# frozen_string_literal: true

# Marks a new user as onboarded and optionally seeds guided sample content.
class Onboarding
  include ActiveModel::Validations, ActiveModel::Model

  SAMPLE_DATA = YAML.safe_load_file(Rails.root.join('config/onboarding_sample_data.yml'), aliases: false)
                    .deep_symbolize_keys.freeze
  TIMELINE_BULLETS = SAMPLE_DATA.fetch(:timeline).freeze
  TIMELINE_YESTERDAY_BULLETS = SAMPLE_DATA.fetch(:timeline_yesterday).freeze
  UPCOMING_BULLETS = SAMPLE_DATA.fetch(:upcoming).freeze
  COLLECTIONS = SAMPLE_DATA.fetch(:collections).freeze

  attr_accessor :user, :data_seed

  validates :user, presence: true

  def complete
    return false unless valid?

    ActiveRecord::Base.transaction { provision! }

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  def data_seed?
    %w[true 1].include?(data_seed.to_s)
  end

  private

  def provision!
    user.update!(onboarded: true)
    seed_sample_data! if data_seed?
  end

  def seed_sample_data!
    return if user.bullets.any?

    create_bullets!(TIMELINE_BULLETS, pops_on: Date.current)
    create_bullets!(TIMELINE_YESTERDAY_BULLETS, pops_on: Date.yesterday)
    seed_upcoming!
    seed_collections!
  end

  def seed_upcoming!
    UPCOMING_BULLETS.each do |definition|
      create_bullets!([definition.except(:days_ahead)], pops_on: Date.current + definition.fetch(:days_ahead).days)
    end
  end

  def seed_collections!
    COLLECTIONS.each do |attributes|
      collection = user.collections.create!(attributes.slice(:name, :icon, :colour, :description))
      create_bullets!(attributes[:bullets], collection: collection)
    end
  end

  def create_bullets!(definitions, pops_on: Date.current, collection: nil)
    definitions.each do |definition|
      user.bullets.create!(
        collection: collection,
        pops_on: pops_on,
        bulletable: Text.new,
        **definition.except(:type)
      )
    end
  end
end
