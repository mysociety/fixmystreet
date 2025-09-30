package FixMyStreet::App::Form::Waste::AboutYou;

use utf8;

use FixMyStreet::SMS;
use HTML::FormHandler::Moose::Role;

with 'FixMyStreet::App::Form::Waste::AboutYou::Shared';

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
    messages => {
        required => 'Your name is required',
    },
);

sub default_name {
    my $self = shift;
    if (my $user = $self->non_staff_user) {
        return $user->name;
    }
}

1;
