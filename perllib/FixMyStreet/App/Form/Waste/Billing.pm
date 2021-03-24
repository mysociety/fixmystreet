package FixMyStreet::App::Form::Waste::Billing;

use utf8;
use HTML::FormHandler::Moose::Role;
use FixMyStreet::SMS;

has_field payment_method => (
    type => 'Select',
    label => 'How do you want to pay?',
    required => 1,
    widget => 'RadioGroup',
    options => [
        { value => 'direct_debit', label => 'Direct Debit', hint => 'Set up your payment details once, and we’ll automatically renew your subscription each year, until you tell us to stop. You can cancel or amend at any time.' },
        { value => 'credit_card', label => 'Debit or Credit Card' },
    ],
);

has_field billing_differ => (
    type => 'Checkbox',
    option_label => 'Check if different to collection address',
    label => "Billing address",
    tags => {
        toggle => 'form-billing_address-row'
    },
);

has_field billing_address => (
    type => 'Text',
    widget => 'Textarea',
    label => "Billing address",
);

has_field name => (
    type => 'Text',
    label => 'Your name',
    required => 1,
    validate_method => sub {
        my $self = shift;
        $self->add_error('Please enter your full name.')
            if length($self->value) < 5
                || $self->value !~ m/\s/
                || $self->value =~ m/\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    },
);

has_field phone => (
    type => 'Text',
    label => 'Telephone number',
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_field email => (
    type => 'Email',
);

1;
