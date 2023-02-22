# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class InvitationEmailPathBuilder
  include InvitationEmailPathManager

  class << self
    def build_and_initialize(event_location:, event_format:, event_type:, attendance:)
      path = build_path(
        event_location: event_location,
        event_format: event_format,
        event_type: event_type,
        attendance: attendance
      )

      new(path: path)
    end
  end

  def initialize(path:)
    @path = path
  end

  private

  attr_reader :path
end
