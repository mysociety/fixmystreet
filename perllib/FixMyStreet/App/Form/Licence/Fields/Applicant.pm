package FixMyStreet::App::Form::Licence::Fields::Applicant;

use utf8;
use HTML::FormHandler::Moose::Role;
use FixMyStreet::SMS;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::Applicant - Applicant fields for licence forms

=head1 DESCRIPTION

Provides additional applicant fields used by TfL licence forms:
organisation, address, phone_24h

=cut

has_field organisation => (
    type => 'Text',
    label => 'Company name',
    required => 1,
);

has_field name => (
    type => 'Text',
    label => 'Applicant full name',
    required => 1,
    validate_method => sub {
        my $self = shift;
        $self->add_error('Please enter your full name.')
            if length($self->value) < 5 || $self->value !~ m/\s/;
    },
);

has_field job_title => (
    type => 'Text',
    label => 'Job title',
    required => 1,
);

has_field address => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Company address',
    required => 1,
    tags => { hint => 'Including postcode' },
);

has_field email => (
    required => 1,
    type => 'Email',
    label => 'Email address',
);

has_field phone => (
    required => 1,
    type => 'Text',
    label => 'Telephone number',
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_field phone_24h => (
    type => 'Text',
    label => 'Emergency telephone number 24/7',
    required => 1,
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

1;
