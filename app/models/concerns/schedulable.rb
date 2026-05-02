module Schedulable
  extend ActiveSupport::Concern

  def schedule!(scheduled_on: nil)
    attrs = { triaged_at: triaged_at || Time.current }
    attrs[:scheduled_on] = scheduled_on if scheduled_on.present?
    update!(attrs)
  end
end
