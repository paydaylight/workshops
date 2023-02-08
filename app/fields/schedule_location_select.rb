# frozen_string_literal: true

class ScheduleLocationSelect < Administrate::Field::Select
  def to_partial_path
    "/fields/#{Administrate::Field::Select.field_type}/#{page}"
  end

  private

  def collection
    GetSetting.location_rooms(resource&.event&.location)
  end
end
