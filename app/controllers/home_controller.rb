class HomeController < ApplicationController
  def show
    @sections = sections.select(&:visible?)
    @appearance = appearance
  end

  private

  def sections
    [
      Section.new(
        name: 'Logs',
        records: logs_records,
        show_path: nil,
        expanded: section_expanded?(:logs)
      ),
      Section.new(
        name: 'Projects',
        records: project_records,
        show_path: projects_path,
        expanded: section_expanded?(:projects)
      ),
      Section.new(
        name: 'People',
        records: person_records,
        show_path: people_path,
        expanded: section_expanded?(:people)
      ),
      Section.new(
        name: 'Collections',
        records: collection_records,
        show_path: collections_path,
        expanded: section_expanded?(:collections)
      ),
      Section.new(
        name: 'Trackers',
        records: tracker_records,
        show_path: trackers_path,
        expanded: section_expanded?(:trackers)
      ),
      Section.new(
        name: 'Published',
        records: published_records,
        show_path: published_index_path,
        expanded: section_expanded?(:published)
      )
    ]
  end

  def logs_records
    Current.user.future_buckets.limit(5).to_a + Current.user.monthly_buckets.limit(5).to_a
  end

  def collection_records
    Current.user.active_collections.limit(5)
  end

  def person_records
    Current.user.mentions.person.limit(5)
  end

  def project_records
    Current.user.mentions.project.limit(5)
  end

  def tracker_records
    Current.user.trackers.open.chronological.limit(5)
  end

  def published_records
    Current.user.published_entities
           .includes(publishable: { bulletable: :rich_text_body })
           .order(published_at: :desc)
           .limit(5)
  end

  def appearance
    Current.user.settings!.appearance
  end

  def section_expanded?(section_name)
    column = User::Settings::SECTION_COLUMNS[section_name.to_s] || User::Settings::SECTION_COLUMNS[section_name]
    Current.user.settings![column]
  end

  Section = Struct.new(:name, :records, :show_path, :expanded, keyword_init: true) do
    def visible?
      records.present?
    end
  end
end
