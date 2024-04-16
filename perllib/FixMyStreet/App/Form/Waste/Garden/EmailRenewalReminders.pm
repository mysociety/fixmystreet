package FixMyStreet::App::Form::Waste::Garden::EmailRenewalReminders;

use utf8;
use HTML::FormHandler::Moose::Role;

has_field email_renewal_reminders => (
    type => 'Select',
    label => 'Would you like an email renewal reminder for next year?',
    default => 'No',
    options => [
        { label => 'No', value => 'No' },
        { label => 'Yes', value => 'Yes' },
    ],
    widget => 'RadioGroup',
    required => 1,
);

1;
