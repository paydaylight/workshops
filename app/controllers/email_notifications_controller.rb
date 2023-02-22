# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class EmailNotificationsController < ApplicationController
  before_action :authorize_user
  before_action :set_variables, only: %i[show new]

  def index
    redirect_to email_notification_path('default', Membership::INVITATION_ATTENDANCE.first)
  end

  def new
    @email_notification = EmailNotification.new
  end

  def show
    @email_notifications = if @current_location == 'default'
                             EmailNotification.where("path like '/default/#{@current_status}'")
                           else
                             EmailNotification.where("path like '/#{@current_location}/%/#{@current_status}'")
                           end
    @email_notifications = @email_notifications.group_by(&:group_by_value)
  end

  def upsert
    email_notification = if notification_params[:id].present?
                           EmailNotification.find(notification_params[:id])
                         else
                           EmailNotification.new(handler: 'liquid', format: 'html')
                         end

    new_path = InvitationEmailPathBuilder.build_path(
      event_location: notification_params[:new_location],
      event_type: notification_params[:new_event_type],
      event_format: notification_params[:new_event_format],
      attendance: notification_params[:new_attendance]
    )

    service = UpsertEmailNotification.new(
      user: current_user,
      email_notification: email_notification,
      params: upsert_service_params.merge(new_path: new_path)
    )
    service.call

    redirect_to email_notification_path(params[:location], params[:attendance])
  end

  def destroy
    email_notification = EmailNotification.find(destroy_params[:id])

    service = UpsertEmailNotification.new(
      user: current_user,
      email_notification: email_notification,
      params: destroy_params.merge(destroy: true)
    )
    service.call

    redirect_to email_notification_path(params[:location], params[:attendance])
  end

  private

  def authorize_user
    authorize current_user, :admin?
  end

  def set_variables
    @locations = GetSetting.locations + %w[default].freeze
    @attendance = Membership::INVITATION_ATTENDANCE
    @event_types = Setting.Site['event_types']
    @event_formats = Setting.Site['event_formats']

    @current_location = params[:location]
    @current_status = params[:attendance]
  end

  def notification_params
    params.require(:email_notification).permit(:id, :new_event_format, :new_event_type,
                                               :new_location, :new_attendance, :body)
  end

  def upsert_service_params
    notification_params.slice(:body, :new_path)
  end

  def destroy_params
    params.permit(:id)
  end
end
