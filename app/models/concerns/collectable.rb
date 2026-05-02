module Collectable
  extend ActiveSupport::Concern

  def collect!(project_id: nil, project_name: nil)
    attrs = { triaged_at: triaged_at || Time.current }
    attrs[:project_id] = project_id unless project_id.nil?
    attrs[:project_name] = project_name unless project_name.nil?
    update!(attrs)
  end
end
