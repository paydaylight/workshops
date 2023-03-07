# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
class ReportsController < ApplicationController
  before_action :set_event, only: %i[event_form summary export]
  before_action :set_defaults, only: %i[event_form select_events_form]

  # GET /events/:event_id/export
  def event_form
    authorize @event, :generate_report?

    if @event.memberships.count.zero?
      flash[:error] = I18n.t('ui.flash.empty_event_members')
      @disable_inputs = true
    end
  end

  # GET /events/:event_id/summary
  def summary
    authorize @event, :see_summary?

    result = ExportEventMembers.new(event_ids: [@event.id], options: summary_options).call(to: :table)

    if result.valid?
      @report = result.report
    else
      flash[:error] = result.error_message
      redirect_to event_report_path(@event)
    end
  end

  # POST /events/:event_id/export
  def export
    authorize @event, :generate_report?

    result = ExportEventMembers.new(event_ids: [@event.id], options: report_params).call

    if result.valid?
      send_data result.report, filename: "event-members-#{@event.code}-#{Date.today}.csv"
    else
      flash[:error] = result.error_message
      redirect_to event_report_path(@event)
    end
  end

  # GET /report
  def select_events_form
    authorize current_user, :admin?

    @date_range_form = true
  end

  # POST /report
  def export_events
    authorize current_user, :admin?

    start_date = params[:start_date]
    end_date = params[:end_date]

    if start_date >= end_date
      flash[:error] = I18n.t('ui.flash.invalid_date_range')
      return redirect_to events_report_path
    end

    event_ids = Event.in_range(start_date, end_date).pluck(:id)

    result = ExportEventMembers.new(event_ids: event_ids, options: report_params).call

    if result.valid?
      send_data result.report, filename: "event-members-#{start_date}-to-#{end_date}.csv"
    else
      flash[:error] = result.error_message
      redirect_to event_report_path(@event)
    end
  end

  private

  def report_params
    params.permit(
      *(
        EventMembersPresenter::ALL_FIELDS +
        EventMembersPresenter::ATTENDANCE_TYPES +
        EventMembersPresenter::ROLES +
        EventMembersPresenter::EVENT_FORMATS
      )
    )
  end

  def summary_options
    @summary_options ||= EventMembersPresenter::SUMMARY_FIELDS.map { |field| [field, '1'] }.to_h
  end

  def set_defaults
    @disable_inputs = false
    @date_range_form = false
  end
end
