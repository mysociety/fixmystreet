package FixMyStreet::App::Form::Waste::Garden::EmailRenewalReminders;

use utf8;
use HTML::FormHandler::Moose::Role;

has_field email_renewal_reminders => (
    type => 'Select',
    label => 'Would you like an email renewal reminder for next year?',
    default => 'Yes',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
    widget => 'RadioGroup',
    required => 1,
);

1;
