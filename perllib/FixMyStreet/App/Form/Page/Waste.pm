=head1 NAME

FixMyStreet::App::Form::Page::Waste

=head1 SYNOPSIS

A subclass of the Simple page to provide a title field that can be set directly
or built via build_title_method, and an override template.

=cut

package FixMyStreet::App::Form::Page::Waste;
use Moose;
extends 'FixMyStreet::App::Form::Page::Simple';

# Title to use for this page
has title => ( is => 'ro', isa => 'Str', lazy => 1, builder => 'build_title' );

has build_title_method => ( is => 'rw', isa => 'CodeRef',
    traits => ['Code'], handles => { 'build_title' => 'execute_method' },
);

# Special template to use in preference to the default
has template => ( is => 'ro', isa => 'Str' );

1;
