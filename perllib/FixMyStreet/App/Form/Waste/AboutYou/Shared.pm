package FixMyStreet::App::Form::Waste::AboutYou::Shared;

use utf8;

use FixMyStreet::SMS;
use HTML::FormHandler::Moose::Role;

has non_staff_user => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $c = $self->{c};
        return $c->user if $c->user_exists && !($c->user->from_body || $c->user->is_superuser);
    },
);

# Order skips 2 in case first/last name separate (as in Bexley Verify form)

has_field phone => (
    type => 'Text',
    label => 'Telephone number',
    order => 4,
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

sub default_phone {
    my $self = shift;
    if (my $user = $self->non_staff_user) {
        return $user->phone;
    }
}

has_field email => (
    type => 'Email',
    order => 3,
    tags => {
        hint => 'Provide an email address so we can send you order status updates'
    },
);

sub default_email {
    my $self = shift;
    if (my $user = $self->non_staff_user) {
        return $user->email;
    }
}

1;
