module LocationsHelper
  def location_select_options(current)
    location_names = Location.names

    options = location_names.zip(location_names)
    options.unshift([current, current]) unless location_names.include?(current) || current.blank?

    options
  end
end
