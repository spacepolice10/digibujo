module Schedulable
  extend ActiveSupport::Concern
  include Promotable

  def schedule_as_task!(tags: [], date: nil)
    promote_to! Task.new, tags: tags, date: date
  end
end
