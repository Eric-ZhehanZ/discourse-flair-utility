# frozen_string_literal: true

module Jobs
  class AutoAssignFlair < ::Jobs::Scheduled
    every 15.minutes

    def execute(args)
      return unless SiteSetting.flair_utility_enabled
      return unless SiteSetting.flair_utility_auto_assign_rules.present?

      DiscourseFlairUtility.assign_flair_for_all_users
    end
  end
end
