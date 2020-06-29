package FixMyStreet::App::Form::Waste::AboutYou;

use utf8;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

use FixMyStreet::SMS;

has '+field_name_space' => ( default => 'FixMyStreet::App::Form::Field' );

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
    tags => {
        hint => 'If you provide an email address, we can send you order status updates'
    },
);

has_field address_same => (
    type => 'Checkbox',
    label => 'Delivery address',
    default => 1,
    option_label => 'Same as collection address'
);

has_field address => (
    type => 'TextArea',
    label => 'Address for delivery',
    required_when => { address_same => 0 },
);

has_field submit => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

sub validate {
    my $self = shift;
    $self->add_form_error('Please specify at least one of phone or email')
        unless $self->field('phone')->value || $self->field('email')->value;
}

__PACKAGE__->meta->make_immutable;

1;
