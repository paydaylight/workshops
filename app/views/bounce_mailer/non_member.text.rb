Your message (below) was NOT delivered, because it was sent from "<%= @email_from %>", which is not the registered email address of a confirmed member of the <%= @event_code %> event.

If you need help, please send a message to <%= @webmaster %>.

------------------------ Your message below ------------------------

From: <%= @email_from %>
To: <%= @email_to %>
Date: <%= @email_date %>
Subject: <%= @email_subject %>

<%= @email_body %>
