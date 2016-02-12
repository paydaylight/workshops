# Copyright (c) 2016 Brent Kearney. This file is part of Workshops.
# Workshops is licensed under the GNU Affero General Public License
# as published by the Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class SyncEventMembersJob < ActiveJob::Base
  require 'sucker_punch/async_syntax'
  queue_as :urgent

  rescue_from(RuntimeError) do |error|
    if error.message == 'NoResultsError'
      retry_job wait: 5.minutes, queue: :default
    end
  end

  def perform(event)
    SyncMembers.new(event).run
  end
end

