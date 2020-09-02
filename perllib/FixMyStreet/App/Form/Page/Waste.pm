package FixMyStreet::App::Form::Page::Waste;
use Moose;
extends 'FixMyStreet::App::Form::Page::Simple';

# Title to use for this page
has title => ( is => 'ro', isa => 'Str' );

# Special template to use in preference to the default
has template => ( is => 'ro', isa => 'Str' );

1;
