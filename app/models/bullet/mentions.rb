# frozen_string_literal: true

class Bullet
  class Mentions
    def initialize(bullet)
      @bullet = bullet
    end

    def projects
      @projects ||= Projects.new(@bullet)
    end

    def people
      @people ||= People.new(@bullet)
    end

    class Projects
      def initialize(bullet)
        @bullet = bullet
      end

      def add!(project_id:)
        project = @bullet.user.projects.find(project_id)
        @bullet.bullet_projects.find_or_create_by!(project: project)
        @bullet.association(:projects).reset
        @bullet.record_activity!('project_mentioned')
      end

      def remove!(project_id:)
        @bullet.bullet_projects.where(project_id: project_id).destroy_all
        @bullet.record_activity!('project_unmentioned')
      end

      def clear!
        return if @bullet.bullet_projects.none?

        @bullet.bullet_projects.destroy_all
        @bullet.association(:projects).reset
        @bullet.record_activity!('project_unmentioned')
      end
    end

    class People
      def initialize(bullet)
        @bullet = bullet
      end

      def add!(person_id:)
        person = @bullet.user.people.find(person_id)
        @bullet.bullet_people.find_or_create_by!(person: person)
        @bullet.association(:people).reset
        @bullet.record_activity!('person_mentioned')
      end

      def remove!(person_id:)
        @bullet.bullet_people.where(person_id: person_id).destroy_all
        @bullet.record_activity!('person_unmentioned')
      end

      def clear!
        return if @bullet.bullet_people.none?

        @bullet.bullet_people.destroy_all
        @bullet.association(:people).reset
        @bullet.record_activity!('person_unmentioned')
      end
    end
  end
end
