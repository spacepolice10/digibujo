module Schedulable
  extend ActiveSupport::Concern

  def schedule!(date: nil)
    attrs = { triaged_at: triaged_at || Time.current }
    attrs[:date] = date if date.present?
    update!(attrs)
  end
end
