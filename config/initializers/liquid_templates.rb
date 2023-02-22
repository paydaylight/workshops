# frozen_string_literal: true

ActiveSupport.on_load(:action_view) do
  ActionView::Template.register_template_handler(:liquid, Liquid::Handler)
end
