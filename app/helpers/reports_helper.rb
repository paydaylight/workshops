# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

module ReportsHelper
  def fields_helper_object
    [
      { label: 'Default fields', checked: true, i18n_key: 'event_report.default_fields' },
      { label: 'Optional fields', checked: false, i18n_key: 'event_report.optional_fields' }
    ]
  end
end
