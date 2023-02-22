# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class EmailNotification < ApplicationRecord
  validates :format,  inclusion: Mime::SET.symbols.map(&:to_s)
  validates :handler, inclusion: ActionView::Template::Handlers.extensions.map(&:to_s)

  include InvitationEmailPathManager

  def self.resolver_lookup(path:)
    path_builder = InvitationEmailPathBuilder.new(path: path)

    if exists?(path: path_builder.build_path)
      where(path: path_builder.build_path)
    elsif exists?(path: path_builder.default_path)
      where(path: path_builder.default_path)
    else
      []
    end
  end

  def group_by_value
    event_type || I18n.t('email_notifications.default').capitalize
  end
end
