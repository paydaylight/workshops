# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
#
# Partially derived from https://github.com/chamnap/liquid-rails/blob/master/lib/liquid-rails/template_handler.rb and
# https://boringrails.com/tips/rails-liquid-dynamic-user-content

module Liquid
  # Allows rendering views as liquid with context from controller
  class Handler
    include ActionView::Helpers::TextHelper

    def self.call(template)
      "Liquid::Handler.new(self).render(#{template.source.inspect}, local_assigns)"
    end

    def initialize(view)
      @view = view
      @controller = @view.controller
    end
    
    def render(template, _options)
      context = if @controller.respond_to?(:liquid_context, true)
                  @controller.send(:liquid_context)
                else
                  @view.assigns
                end

      liquid = Liquid::Template.parse(template)
      simple_format(liquid.render!(context))
    rescue Liquid::Error
      simple_format(template.to_s)
    end

    def compilable?
      false
    end
  end
end
