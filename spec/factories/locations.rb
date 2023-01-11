# frozen_string_literal: true

require 'factory_bot_rails'
require 'faker'

FactoryBot.define do
  factory :location do |f|
    f.name { Faker::Address.street_name }
    f.clarification { 'Street name' }
  end
end
