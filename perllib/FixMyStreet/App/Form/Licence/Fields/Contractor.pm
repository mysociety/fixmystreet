package FixMyStreet::App::Form::Licence::Fields::Contractor;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::Contractor - Contractor fields for licence forms

=head1 DESCRIPTION

Provides contractor/principal contractor fields used by TfL licence forms.
All fields except contractor_same_as_applicant are conditionally required
and hidden based on the "same as applicant" checkbox state.

=cut

has_field contractor_same_as_applicant => (
    type => 'Checkbox',
    label => 'Same as applicant details',
    tags => {
        hint => 'Check this box if the principal contractor details are the same as the applicant',
    },
    option_label => 'Same as applicant',
);

has_field contractor_organisation => (
    type => 'Text',
    label => 'Organisation name',
    required_when => { 'contractor_same_as_applicant' => sub { !$_[0] } },
);

has_field contractor_contact_name => (
    type => 'Text',
    label => 'Contact name',
    required_when => { 'contractor_same_as_applicant' => sub { !$_[0] } },
    validate_method => sub {
        my $self = shift;
        $self->add_error('Please enter your full name.')
            if length($self->value) < 5
                || $self->value !~ m/\s/
                || $self->value =~ m/\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    },
);

has_field contractor_address => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Full address',
    required_when => { 'contractor_same_as_applicant' => sub { !$_[0] } },
    tags => {
        hint => 'Including postcode',
    },
);

has_field contractor_email => (
    type => 'Email',
    label => 'Email address',
    required_when => { 'contractor_same_as_applicant' => sub { !$_[0] } },
);

has_field contractor_phone => (
    type => 'Text',
    label => 'Telephone number (9am-5pm)',
    required_when => { 'contractor_same_as_applicant' => sub { !$_[0] } },
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_field contractor_phone_24h => (
    type => 'Text',
    label => 'Telephone number (24/7)',
    required_when => { 'contractor_same_as_applicant' => sub { !$_[0] } },
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

1;
