# frozen_string_literal: true

module Poppable
  extend ActiveSupport::Concern

  def pop!(pops_on:)
    from = self.pops_on
    update!(pops_on: pops_on)

    if from != pops_on
      mark_migration!(
        action: 'popped',
        from_pops_on: from,
        to_pops_on: pops_on
      )
    else
      record_activity!('popped')
    end
  end

  def unpop!(previous_pops_on:)
    update!(pops_on: previous_pops_on)
  end
end
