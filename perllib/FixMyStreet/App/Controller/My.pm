package FixMyStreet::App::Controller::My;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::My - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub my : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach( '/auth/redirect' ) unless $c->user;

    # Even though front end doesn't yet have it, have it on this page, it's better!
    FixMyStreet::Map::set_map_class( 'FMS' );

    my $p_page = $c->req->params->{p} || 1;
    my $u_page = $c->req->params->{u} || 1;

    my $pins = [];
    my $problems = {};
    my $rs = $c->user->problems->search( undef,
        { rows => 50 } )->page( $p_page );

    while ( my $problem = $rs->next ) {
        push @$pins, {
            latitude  => $problem->latitude,
            longitude => $problem->longitude,
            colour    => $problem->state eq 'fixed' ? 'green' : 'red',
            id        => $problem->id,
            title     => $problem->title,
        };
        push @{ $problems->{$problem->state} }, $problem;
    }
    $c->stash->{problems_pager} = $rs->pager;
    $c->stash->{problems} = $problems;

    $rs = $c->user->comments->search(
        { state => 'confirmed' },
        { rows => 50 } )->page( $u_page );
    my @updates = $rs->all;
    $c->stash->{updates} = \@updates;
    $c->stash->{updates_pager} = $rs->pager;

    FixMyStreet::Map::display_map(
        $c,
        latitude  => $pins->[0]{latitude},
        longitude => $pins->[0]{longitude},
        pins      => $pins,
        any_zoom  => 1,
    )
        if @$pins;
}

__PACKAGE__->meta->make_immutable;

1;
