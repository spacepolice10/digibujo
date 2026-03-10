module Promotable
  extend ActiveSupport::Concern

  private

  def promote_to!(new_cardable, tag_names: [])
    transaction do
      new_cardable.save!
      card.update!(cardable: new_cardable)
      if tag_names.any?
        card.tag_names = tag_names.join(", ")
        card.save!
      end
      association(:card).reset # force re-query so dependent: :destroy finds nothing
      destroy!
    end
  end
end
