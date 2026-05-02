module ProjectAssignable
  extend ActiveSupport::Concern

  included do
    attribute :project_name, :string

    after_initialize do
      unless project_name_changed?
        self.project_name = project&.name.to_s
        clear_attribute_changes([:project_name])
      end
    end

    before_save :assign_project, if: -> { project_name_changed? }
  end

  private

  def assign_project
    normalized_name = normalize_project_name(project_name)

    if normalized_name.blank?
      self.project = nil
      return
    end

    self.project = find_or_create_project_by_name!(normalized_name)
  end

  def find_or_create_project_by_name!(normalized_name)
    user.projects.find_or_create_by!(name: normalized_name)
  end

  def normalize_project_name(name)
    name.to_s.strip.downcase
  end
end
