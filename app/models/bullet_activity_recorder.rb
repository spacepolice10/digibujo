# frozen_string_literal: true

class BulletActivityRecorder
  class << self
    def record_updated!(bullet:)
      record!(bullet:, action: "updated")
    end

    def record_archived!(bullet:)
      record!(bullet:, action: "archived")
    end

    def record_collected!(bullet:)
      record!(bullet:, action: "collected")
    end

    def record_project_tagged!(bullet:)
      record!(bullet:, action: "project_tagged")
    end

    def record_project_untagged!(bullet:)
      record!(bullet:, action: "project_untagged")
    end

    def record_person_tagged!(bullet:)
      record!(bullet:, action: "person_tagged")
    end

    def record_person_untagged!(bullet:)
      record!(bullet:, action: "person_untagged")
    end

    def record_popped!(bullet:)
      record!(bullet:, action: "popped")
    end

    def record_completed!(bullet:)
      record!(bullet:, action: "completed")
    end

    def record_uncompleted!(bullet:)
      record!(bullet:, action: "uncompleted")
    end

    private

    def record!(bullet:, action:)
      BulletActivity.create!(user: bullet.user, bullet_id: bullet.id, action: action)
    end
  end
end
