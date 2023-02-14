# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
require 'csv'

class ExportEventMembers
  include EventMembersPresenter

  MULTISELECT_OPTIONS = %i[event_format attendance role].freeze

  Result = Struct.new(:report, :error_message, keyword_init: true) do
    def valid?
      error_message.nil? && report
    end
  end

  def initialize(event_ids:, options:)
    @event_ids = event_ids
    @options = options
  end

  def call
    return Result.new(error_message: I18n.t('ui.error_messages.no_options_selected')) if empty_fields?

    csv = to_csv

    Result.new(report: csv)
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
        memberships_by_attendance(event).each do |attendance, memberships|
          next unless include_attendance?(attendance)
          next unless include_event_format?(event.event_format)

          memberships.each do |membership|
            next unless include_roles?(membership.role)

            csv << row(membership)
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
    end
  end

  def selected_options
    @selected_options ||= filter_options(ALL_FIELDS)
  end

  def attendance_options
    @attendance_options ||=
      filter_options(ATTENDANCE_TYPES).map { |key| I18n.t("memberships.attendance.#{key}", locale: :en) }
  end

  def roles_options
    @roles_options ||= filter_options(ROLES).map { |key| I18n.t("memberships.roles.#{key}", locale: :en) }
  end

  def event_format_options
    @event_format_options ||= filter_options(EVENT_FORMATS).map { |key| I18n.t("events.formats.#{key}", locale: :en) }
  end

  def filter_options(template)
    options.select { |field, value| ['1', true].include?(value) && template.include?(field.to_sym) }.keys.map(&:to_sym)
  end

  def memberships_by_attendance(event)
    SortedMembers.new(event).memberships
  end

  def row(membership)
    selected_options.map { |field| cell_field_values[field].call(membership) }
  end

  def empty_fields?
    selected_options.all? { |option| MULTISELECT_OPTIONS.include?(option) }
  end

  def include_attendance?(attendance)
    attendance_options.include?(attendance) || attendance_options.empty?
  end

  def include_roles?(role)
    roles_options.include?(role) || roles_options.empty?
  end

  def include_event_format?(event_format)
    event_format_options.include?(event_format) || event_format_options.empty?
  end
end
