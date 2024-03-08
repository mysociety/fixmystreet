package FixMyStreet::App::Form::Waste::AboutYou;

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
    messages => {
        required => 'Your name is required',
    },
);

has non_staff_user => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $c = $self->{c};
        return $c->user if $c->user_exists && !($c->user->from_body || $c->user->is_superuser);
    },
);

sub default_name {
    my $self = shift;
    if (my $user = $self->non_staff_user) {
        return $user->name;
    }
}

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

sub default_phone {
    my $self = shift;
    if (my $user = $self->non_staff_user) {
        return $user->phone;
    }
}

has_field email => (
    type => 'Email',
    tags => {
        hint => 'Provide an email address so we can send you order status updates'
    },
);

has_field extra_bulky_text_updates => (
    type => 'Checkbox',
    label => 'Bulky text reminders',
    option_label => 'Do you want to receive reminders about this collection by text message?',
    inactive => 1,
);


sub default_email {
    my $self = shift;
    if (my $user = $self->non_staff_user) {
        return $user->email;
    }
}

1;
