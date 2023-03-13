# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

module EventsHelper

  def get_text(field)
    if field.blank?
      field = ''
      if policy(@event).edit?
        field << %q( Please set one by clicking the "Edit Event" button! )
      else
        field = 'No description is set.'
      end
    else
      field = simple_format(field).gsub(/<br><br>/, '').html_safe
    end
    field
  end

  def title_from_path
    title = ''
    case request.path
    when /settings/
      title = 'Application Settings'
    when '/events'
      title = 'All'
    when /events\/my_events/
      title = 'My'
    when /future|past/
      time = request.path.match(/events\/(\w+)/)
      title = time[1].titleize
    when /year/
      year = request.path.match(/year\/(\w+)/)
      title = year[1]
    end
    title
  end

  def event_list_title
    return @heading unless @heading.blank?
    return '' if controller_name == 'registrations'
    title = title_from_path

    if !@kind.blank?
      title = "#{@kind.titleize.pluralize}"
      title += " in #{@year}" unless @year.blank?
    elsif request.path.match(/reports/)
      title = 'Generate Events Report'
    else
      title << " Events"
    end

    location = request.path.match(/location\/(\w+)/)
    title[/Events/] = "#{location[1]} Events" unless location.blank?
    title
  end

  def location_url(location)
    case request.path
    when /past|future/
      '/events/' + action_name + "/location/#{location}"
    when /year/
      "/events/year/#{@year}/location/#{location}"
    else
      events_location_path(location)
    end
  end

  def kind_url(event_type)
    kind = event_type.parameterize
    if @year.blank?
      "/events/kind/#{kind}"
    else
      "/events/kind/#{kind}/year/#{@year}"
    end
  end

  def year_url(year)
    url = events_year_path(year)
    if !@location.blank?
      url = "/events/year/#{year}/location/#{@location}"
    elsif !@kind.blank?
      url = "/events/kind/#{@kind}/year/#{year}"
    end
    url
  end

  def get_year(event, direction)
    year = event.year.to_i - 1
    year = event.year.to_i + 1 if direction == :next
    year
  end

  def year_arrow(direction, year)
    return "← #{year}" if direction == :previous
    "#{year} →"
  end

  def year_path(year)
    if @kind.blank?
      events_year_path(year)
    else
      "/events/kind/#{@kind}/year/#{year}"
    end
  end

  def year_link(event, direction)
    return if event.blank? || request.path.match?(/events\/my_events/)
    year = get_year(event, direction)
    link_to(year_arrow(direction, year), year_path(year))
  end

  def event_cancelled?(event)
    return ' class="cancelled"'.html_safe if event.cancelled
  end

  def location_options
    GetSetting.locations || []
  end

  def events_hash
    @events_hash ||= {}
  end

  def onsite_confirmed_count(event)
    return events_hash["#{event.id}_onsite_confirmed"] if events_hash["#{event.id}_onsite_confirmed"]

    events_hash["#{event.id}_onsite_confirmed"] = Membership.where(
      attendance: 'Confirmed', role: Membership::IN_PERSON_ROLES, event: event
    ).count
  end

  def virtual_confirmed_count(event)
    return events_hash["#{event.id}_virtual_confirmed"] if events_hash["#{event.id}_virtual_confirmed"]

    events_hash["#{event.id}_virtual_confirmed"] = Membership.where(
      attendance: 'Confirmed', role: Membership::ONLINE_ROLES, event: event
    ).count
  end

  def observers_count(event)
    event.confirmed_count - virtual_confirmed_count(event) - onsite_confirmed_count(event)
  end
end
