# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
class ReportsController < ApplicationController
  before_action :set_event, only: %i[current_event export]
  before_action :set_defaults, only: %i[current_event select_events]

  # GET /events/:event_id/export
  def current_event
    policy(@event).generate_report?

    if @event.memberships.count.zero?
      flash[:error] = I18n.t('ui.flash.empty_event_members')
      @disable_inputs = true
    end
  end

  # POST /events/:event_id/export
  def export
    policy(@event).generate_report?

    csv = ExportEventMembers.new(event_ids: [@event.id], options: report_params).call
    send_data csv, filename: "event-members-#{@event.code}-#{Date.today}.csv"
  end

  # GET /report
  def select_events
    policy(current_user).admin?

    @show_datepicker = true
  end

  # POST /report
  def export_in_range
    policy(current_user).admin?

    start_date = params[:start_date]
    end_date = params[:end_date]

    if start_date >= end_date
      flash[:error] = I18n.t('ui.flash.invalid_date_range')
      return redirect_to events_report_path
    end

    event_ids = Event.in_range(start_date, end_date).pluck(:id)
    csv = ExportEventMembers.new(event_ids: event_ids, options: report_params).call

    send_data csv, filename: "event-members-#{start_date}-to-#{end_date}.csv"
  end

  private

  def report_params
    params.permit(*EventMembersPresenter::ALL_FIELDS)
  end

  def set_defaults
    @disable_inputs = false
    @show_datepicker = false
  end
end
