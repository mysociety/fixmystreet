=head1 NAME

FixMyStreet::App::Form::Page::Bulky

=head1 SYNOPSIS

A subclass of the Waste page to provide a different title field,
depending upon the cobrand.

=cut

package FixMyStreet::App::Form::Page::Bulky;
use Moose;
extends 'FixMyStreet::App::Form::Page::Waste';

sub _build_title {
    my $self = shift;

    my $cobrand = $self->form->{c}->cobrand->moniker;
    if ($cobrand =~ /^(kingston|sutton)$/) {
        return 'Book bulky items collection';
    } elsif ( $cobrand eq 'merton' || $cobrand eq 'bexley' ) {
        return 'Book a bulky waste collection';
    } else {
        return 'Book bulky goods collection';
    }
}

1;
