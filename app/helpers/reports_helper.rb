# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

module ReportsHelper
  def fields_helper_object
    [
      { label: I18n.t('event_report.default_field'), checked: true, i18n_key: 'event_report.default_fields' },
      { label: I18n.t('event_report.optional_field'), checked: false, i18n_key: 'event_report.optional_fields' }
    ]
  end

  def multiple_select_fields
    [
      { field: :attendance, i18n_key: 'memberships.attendance' },
      { field: :role, i18n_key: 'memberships.roles' },
      { field: :event_format, i18n_key: 'events.formats' }
    ]
  end
end
