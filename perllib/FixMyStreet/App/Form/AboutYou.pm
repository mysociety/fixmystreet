package FixMyStreet::App::Form::AboutYou;

use utf8;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

use mySociety::PostcodeUtil qw(is_valid_postcode);

has '+field_name_space' => ( default => 'FixMyStreet::App::Form::Field' );

has_field name => (
    type => 'Text',
    label => 'Your name',
    required => 1,
);

has_field phone => (
    type => 'Text',
    label => 'Telephone number',
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

__PACKAGE__->meta->make_immutable;

1;
