package FixMyStreet::App::Form::Page::Noise;
use Moose;
extends 'FixMyStreet::App::Form::Page::Simple';

# Title to use for this page
has title => ( is => 'ro', isa => 'Str' );

# Optional template to display at the top of this page
has intro => ( is => 'ro', isa => 'Str' );

# Special template to use in preference to the default
has template => ( is => 'ro', isa => 'Str' );

# Does this page of the form require you to be signed in?
has requires_sign_in => ( is => 'ro', isa => 'Bool' );

1;
