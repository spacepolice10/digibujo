module Promotable
  extend ActiveSupport::Concern

  private

  def promote_to!(new_cardable, tags: [], date: nil)
    transaction do
      new_cardable.save!
      attrs = { cardable: new_cardable }
      attrs[:date] = date if date.present?
      card.update!(attrs)
      if tags.any?
        card.tags_string = tags.join(", ")
        card.save!
      end
      association(:card).reset # force re-query so dependent: :destroy finds nothing
      destroy!
    end
  end
end
