package FixMyStreet::App::Form::Licence::Fields::Applicant;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::Applicant - Applicant fields for licence forms

=head1 DESCRIPTION

Provides additional applicant fields used by TfL licence forms:
organisation, address, phone_24h

This role should be used alongside FixMyStreet::App::Form::AboutYou
which provides the standard name, email, phone fields.

=cut

has_field organisation => (
    type => 'Text',
    label => 'Organisation name',
    required => 1,
);

has_field address => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Full address',
    required => 1,
    tags => { hint => 'Including postcode' },
);

has_field phone_24h => (
    type => 'Text',
    label => 'Telephone number (24/7)',
    required => 1,
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

1;
