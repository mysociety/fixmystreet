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
        { value => "", label => '-' },
        map { { value => $_, label => $_ } } (1..6),
    ],
};

sub tickbox_options {
    my $quant = shift;
    (
        type => 'Checkbox',
        apply => [
            {
                when => { $quant => sub { $_[0] > 0 } },
                check => qr/^1$/,
                message => 'Please tick the box',
            },
        ],
    )
}

has_field mixed_recycling => (
    tickbox_options('mixed_quantity'),
    label => 'Mixed recycling (cans, plastics & glass recycling)',
    option_label => 'Request a new cans, plastic & glass container' );
has_field mixed_quantity => (
    %$quantity_options,
    required_when => { mixed_recycling => 1 },
);

has_field paper_recycling => (
    tickbox_options('paper_quantity'),
    label => 'Paper (Paper & Cardboard)',
    option_label => 'Request a new paper container' );
has_field paper_quantity => (
    %$quantity_options,
    required_when => { paper_recycling => 1 },
);

has_field kitchen_caddy => (
    tickbox_options('kitchen_quantity'),
    label => 'Kitchen caddy',
    option_label => 'Request a new kitchen caddy container' );
has_field kitchen_quantity => (
    %$quantity_options,
    required_when => { kitchen_caddy => 1 },
);

has_field submit => ( type => 'Submit', value => 'Request new containers', element_attr => { class => 'govuk-button' } );

__PACKAGE__->meta->make_immutable;

1;
