package FixMyStreet::App::Form::BinRequest;

use utf8;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

use mySociety::PostcodeUtil qw(is_valid_postcode);

has '+field_name_space' => ( default => 'FixMyStreet::App::Form::Field' );

my $quantity_options = {
    type => 'Select',
    label => 'Quantity',
    tags => { hint => 'You can request a maximum of six containers' },
    options => [
        { value => 0, label => '-' },
        map { { value => $_, label => $_ } } (1..6),
    ],
};
has_field mixed_recycling => (
    type => 'Checkbox',
    label => 'Mixed recycling (cans, plastics & glass recycling)',
    option_label => 'Request a new cans, plastic & glass container' );
has_field mixed_quantity => ( %$quantity_options );
has_field paper_recycling => (
    type => 'Checkbox',
    label => 'Paper (Paper & Cardboard)',
    option_label => 'Request a new paper container' );
has_field paper_quantity => ( %$quantity_options );
has_field kitchen_caddy => (
    type => 'Checkbox',
    label => 'Kitchen caddy',
    option_label => 'Request a new kitchen caddy container' );
has_field kitchen_quantity => ( %$quantity_options );

has_field submit => ( type => 'Submit', value => 'Request new containers', element_attr => { class => 'govuk-button' } );

__PACKAGE__->meta->make_immutable;

1;
