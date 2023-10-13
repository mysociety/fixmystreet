package FixMyStreet::App::Form::Page::Bulky;
use Moose;
extends 'FixMyStreet::App::Form::Page::Waste';

sub _build_title {
    my $self = shift;

    my $cobrand = $self->form->{c}->cobrand->moniker;
    if ($cobrand =~ /^(kingston|sutton)$/) {
        return 'Book bulky items collection';
    } else {
        return 'Book bulky goods collection';
    }
}

1;
