package FixMyStreet::App::Form::Waste::AccessPaySuiteBankDetails;

use utf8;
use HTML::FormHandler::Moose::Role;
use mySociety::PostcodeUtil;

has_field name_title => (
    type => 'Text',
    required => 1,
    label => 'Title (e.g. Mr, Mrs, Ms, Dr, etc.)',
);

has_field first_name => (
    type => 'Text',
    required => 0,
    label => 'First name',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('First name must be 255 characters or less') if length($self->value) > 255;
    },
);

has_field surname => (
    type => 'Text',
    required => 1,
    label => 'Surname',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Surname must be 255 characters or less') if length($self->value) > 255;
    },
);

has_field address1 => (
    type => 'Text',
    required => 1,
    label => 'Address line 1',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Address line 1 must be 50 characters or less')
            if length($self->value) > 50;
    },
);

has_field address2 => (
    type => 'Text',
    required => 1,
    label => 'Address line 2',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Address line 2 must be 30 characters or less')
            if length($self->value) > 30;
    },
);

has_field address3 => (
    type => 'Text',
    required => 0,
    label => 'Address line 3',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Address line 3 must be 30 characters or less')
            if length($self->value) > 30;
    },
);

has_field address4 => (
    type => 'Text',
    required => 0,
    label => 'Address line 4',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Address line 4 must be 30 characters or less')
            if length($self->value) > 30;
    },
);

has_field post_code => (
    type => 'Text',
    required => 1,
    label => 'Postcode',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Please enter a valid postcode')
            unless mySociety::PostcodeUtil::is_valid_postcode($self->value);
    },
);

has_field account_holder => (
    type => 'Text',
    required => 1,
    label => 'Name of account holder',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        my $value = $self->value;
        # Remove any special characters, keeping only alphanumeric and spaces
        $value =~ s/[^a-zA-Z0-9 ]//g;
        $self->add_error('Account holder name must be 18 characters or less')
            if length($value) > 18;
        # Update the value to the cleaned version
        $self->value($value);
    },
);

has_field account_number => (
    type => 'Text',
    required => 1,
    label => 'Account number',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        # Remove any non-numerical characters
        my $value = $self->value;
        $value =~ s/[^0-9]//g;
        # Update the value to just the numbers
        $self->value($value);
        # Validate it's exactly 8 digits with leading zeros intact
        $self->add_error('Please enter a valid 8 digit account number')
            unless $value =~ /^[0-9]{8}$/;
    },
);

has_field sort_code => (
    type => 'Text',
    required => 1,
    label => 'Sort code',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        my $sort_code = $self->value;
        $sort_code =~ s/[^0-9]//g;
        $self->value($sort_code);
        $self->add_error('Please enter a valid 6 digit sort code')
            unless $sort_code =~ /^\d{6}$/;
    },
);

has_field submit_bank_details => (
    type => 'Submit',
    value => 'Review subscription',
    element_attr => { class => 'govuk-button' },
);

1;
