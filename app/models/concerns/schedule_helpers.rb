# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

module ScheduleHelpers
  extend ActiveSupport::Concern

  def notify_staff?
    event_memo.current?
  end

  def start_time_in_time_zone
    event_memo&.time_zone ? start_time.in_time_zone(event_memo.time_zone) : start_time
  end

  def end_time_in_time_zone
    event_memo&.time_zone ? end_time.in_time_zone(event_memo.time_zone) : end_time
  end

  def times_use_event_timezone
    unless start_time.nil? || end_time.nil? || event_memo.nil?
      start_time.time_zone.name == event_memo.time_zone &&
          end_time.time_zone.name == event_memo.time_zone
    end
  end

  def times_within_event
    schedule_start = start_time_in_time_zone.to_i
    schedule_end = end_time_in_time_zone.to_i
    event_start = event_memo.start_date_in_time_zone.to_i
    event_end = event_memo.end_date_in_time_zone.change({ hour: 23 }).to_i
    if schedule_start < event_start || schedule_start > event_end
      errors.add(:start_time, '- must be within the event dates')
    end

    errors.add(:end_time, '- must be within the event dates') if schedule_end < event_start || schedule_end > event_end
  end

  def missing_data
    event_memo.blank? || start_time.blank? || end_time.blank?
  end

  def ends_after_begins
    errors.add(:end_time, '- must be greater than start time') if end_time <= start_time
  end

  # Schedule items can overlap, but not Lectures
  def errors_or_warnings(field, other)
    if self.is_a?(Schedule)
      add_overlaps_warning(other)
    else
      field = 'time' if field.to_s.match?('_time')
      add_error(field, other)
    end
  end

  def times_overlap
    self.class.where("((start_time, end_time) OVERLAPS
                      (timestamp :start, timestamp :end)) AND id != :myself",
                     start: start_time, end: end_time,
                     myself: id.nil? ? 0 : id).order(:start_time).each { |other| errors_or_warnings(:start_time, other) }
  end

  def clean_data
    # remove leading & trailing whitespace
    attributes.each_value { |v| v.strip! if v.respond_to? :strip! }
  end

  def event_memo
    @even_memo ||= event
  end
end
