# frozen_string_literal: true

# name: discourse-flair-utility
# about: Admin controls for user flair - hide flair picker and auto-assign flair based on group membership
# version: 0.1.0
# authors: Eric-ZhehanZ
# url: https://github.com/Eric-ZhehanZ/discourse-flair-utility
# required_version: 2.7.0

enabled_site_setting :flair_utility_enabled

register_asset "stylesheets/hide-flair-picker.scss"

module ::DiscourseFlairUtility
  PLUGIN_NAME = "discourse-flair-utility"
end

require_relative "lib/discourse_flair_utility/engine"

after_initialize do
  # Auto-assign flair when user is added to a group
  DiscourseEvent.on(:user_added_to_group) do |user, group|
    if SiteSetting.flair_utility_enabled && SiteSetting.flair_utility_auto_assign_rules.present?
      DiscourseFlairUtility.assign_flair_for_user(user)
    end
  end

  # Reassign flair when user is removed from a group
  DiscourseEvent.on(:user_removed_from_group) do |user, group|
    if SiteSetting.flair_utility_enabled && SiteSetting.flair_utility_auto_assign_rules.present?
      DiscourseFlairUtility.assign_flair_for_user(user)
    end
  end

  # Re-apply all flair when the rules setting changes
  DiscourseEvent.on(:site_setting_changed) do |name, _old, _new|
    if name.to_s == "flair_utility_auto_assign_rules" && SiteSetting.flair_utility_enabled
      DiscourseFlairUtility.assign_flair_for_all_users
    end
  end

  module ::DiscourseFlairUtility
    def self.rule_group_ids
      SiteSetting.flair_utility_auto_assign_rules
        .split("|")
        .map(&:strip)
        .reject(&:empty?)
        .map(&:to_i)
    end

    def self.rule_groups
      ids = rule_group_ids
      return [] if ids.empty?
      # Preserve priority order from the setting
      groups_by_id = Group.where(id: ids).index_by(&:id)
      ids.filter_map { |id| groups_by_id[id] }
    end

    def self.assign_flair_for_user(user)
      groups = rule_groups
      return if groups.empty?

      user_group_ids = user.group_users.pluck(:group_id)

      groups.each do |group|
        next unless user_group_ids.include?(group.id)
        next unless group.flair_icon.present? || group.flair_upload_id.present?

        if user.flair_group_id != group.id
          user.update_column(:flair_group_id, group.id)
        end
        return
      end

      # No matching group with flair found — clear flair if it was set by a rule group
      if groups.map(&:id).include?(user.flair_group_id)
        user.update_column(:flair_group_id, nil)
      end
    end

    def self.assign_flair_for_all_users
      groups = rule_groups
      return if groups.empty?

      managed_group_ids = groups.map(&:id)

      User.joins(:group_users).distinct.find_each do |user|
        user_group_ids = user.group_users.pluck(:group_id)
        assigned = false

        groups.each do |group|
          next unless user_group_ids.include?(group.id)
          next unless group.flair_icon.present? || group.flair_upload_id.present?

          if user.flair_group_id != group.id
            user.update_column(:flair_group_id, group.id)
          end
          assigned = true
          break
        end

        unless assigned
          if managed_group_ids.include?(user.flair_group_id)
            user.update_column(:flair_group_id, nil)
          end
        end
      end
    end
  end
end
