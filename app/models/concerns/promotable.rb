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
      destroy! # safe — card no longer points here
    end
  end
end
