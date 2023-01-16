# frozen_string_literal: true

# app/models/location.rb
#
# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
class Location < ApplicationRecord
  include Discard::Model

  validates :name, presence: true

  scope :including_id, ->(id = nil) { id ? where(id: id).or(kept).distinct : kept }

  def self.names_and_ids(id: nil)
    including_id(id).pluck(:name, :id)
  end
end
