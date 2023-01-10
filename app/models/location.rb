# frozen_string_literal: true

# app/models/location.rb
#
# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
class Location < ApplicationRecord
  validates :name, presence: true

  def self.names
    find_each.pluck(:name)
  end
end
