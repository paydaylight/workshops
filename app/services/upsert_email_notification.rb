# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class UpsertEmailNotification
  include Pundit

  def initialize(user:, email_notification:, params:)
    @user = user
    @email_notification = email_notification
    @params = params
  end

  def call
    authorize user, :admin?

    return if maybe_destroy

    maybe_update_body
    maybe_update_path

    save_record
  end

  private

  attr_reader :user, :email_notification, :params
  alias current_user user

  def maybe_update_body
    return unless params[:body] && params[:body] != email_notification.body

    email_notification.body = params[:body]
  end

  def maybe_update_path
    return unless params[:new_path] && params[:new_path] != email_notification.path

    email_notification.path = params[:new_path]
  end

  def maybe_destroy
    return unless params[:destroy] && !email_notification.new_record?

    email_notification.destroy!
  end

  def save_record
    email_notification.save!
  end
end
