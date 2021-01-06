package FixMyStreet::App::Form::AboutYou;

use utf8;
use HTML::FormHandler::Moose::Role;
use FixMyStreet::SMS;

has_field name => (
    type => 'Text',
    label => 'Full name',
    required => 1,
    validate_method => sub {
        my $self = shift;
        $self->add_error('Please enter your full name.')
            if length($self->value) < 5
                || $self->value !~ m/\s/
                || $self->value =~ m/\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    },
);

has_field email => (
    required => 1,
    type => 'Email',
    label => 'Email address',
    tags => {
        hint => sub { shift->form->email_hint },
    },
);

has_field phone => (
    required => 1,
    type => 'Text',
    label => 'Telephone number',
    tags => {
        hint => sub { shift->form->phone_hint },
    },
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

1;
