package FixMyStreet::App::Form::Page::Simple;
use Moose;
extends 'HTML::FormHandler::Page';

# What page to go to after successful submission of this page
has next => ( is => 'ro', isa => 'Str|CodeRef' );

# A function that will be called to generate an update_field_list parameter
has update_field_list => (
    is => 'ro',
    isa => 'CodeRef',
    predicate => 'has_update_field_list',
);

# A function called after all form processing, just before template display
# (to e.g. set up the map)
has post_process => (
    is => 'ro',
    isa => 'CodeRef',
);

has check_unique_id => ( is => 'ro', default => 1 );

# Catalyst action to forward to once this page has been reached
has finished => ( is => 'ro', isa => 'CodeRef' );

1;
