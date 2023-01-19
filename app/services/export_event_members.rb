# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class ExportEventMembers
  include EventMembersPresenter

  def initialize(event_ids:, options:)
    @event_ids = event_ids
    @options = options
  end

  def call
    to_csv
  end

  private

  attr_reader :event_ids, :options

  def events
    Event.where(id: event_ids).find_each
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << headers
      events.each do |event|
        memberships_by_attendance(event).each do |_attendance, members|
          members.each do |member|
            csv << row(member, event.code)
          end
        end
      end
    end
  end

  def headers
     selected_options.map do |field|
      if DEFAULT_FIELDS.include?(field)
        I18n.t("event_report.default_fields.#{field}")
      else
        I18n.t("event_report.optional_fields.#{field}")
      end
    end.unshift(I18n.t('event_report.event_code'))
  end

  def selected_options
    @selected_options ||= options.select { |_, option| option == "1" }.keys.map(&:to_sym)
  end

  def memberships_by_attendance(event)
    SortedMembers.new(event).memberships
  end

  def row(membership, event_code)
    selected_options.map { |field| cell_field_values[field].call(membership) }.unshift(event_code)
  end
end
