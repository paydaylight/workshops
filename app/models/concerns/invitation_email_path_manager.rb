# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

module InvitationEmailPathManager
  extend ActiveSupport::Concern

  class_methods do
    def build_path(event_location:, event_format:, event_type:, attendance:)
      return unless event_location && event_format && event_type && attendance

      "/#{event_location}/#{event_format}/#{event_type}/#{attendance}"
    end
  end

  def event_location
    @event_location ||= GetSetting.locations.find(&finder_block)
  end

  def event_type
    @event_type ||= Setting.Site['event_types'].find(&finder_block)
  end

  def event_format
    @event_format ||= Setting.Site['event_formats'].find(&finder_block)
  end

  def attendance
    @attendance ||= Membership::INVITATION_ATTENDANCE.find(&finder_block)
  end

  def build_path
    @build_path ||= if event_location && event_type && event_format && attendance
                      self.class.build_path(
                        event_location: event_location,
                        event_type: event_type,
                        event_format: event_format,
                        attendance: attendance
                      )
                    else
                      default_path
                    end
  end

  def default_path
    return @default_path if defined?(@default_path)

    @default_path = "/default/#{attendance}" if attendance
  end

  private

  def finder_block
    @finder_block ||= ->(path_part) { path&.include?("/#{path_part}") }
  end
end
