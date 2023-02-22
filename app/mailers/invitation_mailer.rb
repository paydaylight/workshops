# Copyright (c) 2019 Banff International Research Station
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class InvitationMailer < ApplicationMailer
  prepend_view_path Liquid::Resolver.instance

  def invite(invitation)
    @invitation = invitation
    @person = invitation.membership.person
    @event = invitation.membership.event

    subject = "#{@event.location} Workshop Invitation: #{@event.name} (#{@event.code})"
    recipients = InvitationEmailRecipients.new(invitation).compose

    headers['X-BIRS-Sender'] = invitation.invited_by.to_s
    headers['X-BIRS-Event'] = invitation.event.code.to_s
    headers['X-Priority'] = 1
    headers['X-MSMail-Priority'] = 'High'

    mail(
      to: recipients[:to],
      bcc: recipients[:bcc],
      from: recipients[:from],
      subject: subject,
      template_path: @invitation.email_template_path
    )
  end

  def liquid_context
    {
      'person_dear_name' => @person.dear_name,
      'invitation_date' => @invitation.invited_on.strftime('%A, %B %-d, %Y'),
      'event_name' => @event.name,
      'event_location' => @event.location,
      'event_code' => @event.code,
      'rsvp_url' => @invitation.rsvp_url,
      'rsvp_deadline' => RsvpDeadline.new(@event, DateTime.current, @invitation.membership).rsvp_by,
      'event_start' => @event.start_date_formatted,
      'event_end' => @event.end_date_formatted,
      'organizers' => PersonWithAffilList.compose(@event.organizers)
    }
  end
end
