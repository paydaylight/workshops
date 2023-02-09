# Copyright (c) 2023 Banff International Research Station
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be included in all copies
# or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Syncs default locations
namespace :sync_locations do
  task default: 'sync_locations:rooms'

  def location_setting
    @location_setting ||= Setting.find_by(var: 'Locations')
  end

  FileNotFoundError = StandardError

  def yml_settings
    return @yml_settings if defined?(@yml_settings)

    raise FileNotFoundError unless File.exist?(yml_path)

    @yml_settings = YAML.load_file(yml_path)
  end

  def yml_path
    @yml_path ||= Rails.root.join('config', 'locations.yml')
  end

  desc 'Makes sure that default locations and rooms are up to date'
  task rooms: :environment do
    locations = yml_settings['locations']
    db_locations = location_setting.value.dup

    locations.each do |name, settings|
      if db_locations[name]
        p "Updating rooms for #{name}"
        db_locations[name]['rooms'] = settings['rooms']
      else
        p "Did not found #{name} in site settings, doing nothing..."
        next
      end
    end

    begin
      location_setting.update!(value: db_locations)
      p 'Saved location rooms'
    rescue StandardError => e
      p "Error occurred: #{e}"
    end
  rescue FileNotFoundError
    p "Did not found YAML file at #{yml_path}."
  end
end
