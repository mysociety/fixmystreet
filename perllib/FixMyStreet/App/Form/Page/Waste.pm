package FixMyStreet::App::Form::Page::Waste;
use Moose;
extends 'FixMyStreet::App::Form::Page::Simple';

# Title to use for this page
has title => ( is => 'ro', 'isa' => 'Str', lazy => 1, builder => '_build_title' );
# So we can insert cobrand specific service name
has title_ggw => ( is => 'ro', isa => 'Str' );

sub _build_title {
    my $self = shift;
    my $name = $self->form->{c}->cobrand->garden_service_name;
    return sprintf($self->title_ggw, $name);
}

# Special template to use in preference to the default
has template => ( is => 'ro', isa => 'Str' );

1;
