# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

namespace :email_templates do
  desc 'Sets up default email invitation templates for each attendance status'
  task set_up_default: :environment do
    Membership::ATTENDANCE.each do |status|
      template = EmailNotification.find_or_initialize_by(
        handler: 'liquid',
        format: 'html',
        default: true,
        path: "/default/#{status}"
      )
      template.save! if template.new_record?

      p "Saved default template for status #{status}"
    end
  end
end
