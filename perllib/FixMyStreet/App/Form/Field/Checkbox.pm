package FixMyStreet::App::Form::Field::Checkbox;

# Same as HTML::FormHandler, but easier customisation of the option label and hint

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Checkbox';

has 'option_label' => (
    is => 'rw',
    lazy => 1,
    builder => 'build_option_label',
);

has build_option_label_method => (
    is => 'rw',
    isa => 'CodeRef',
    traits => ['Code'],
    handles => { 'build_option_label' => 'execute_method' },
);

has 'option_hint' => (
    is => 'rw',
    lazy => 1,
    default => '',
);

1;
