package FixMyStreet::App::Controller::Around;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Map;
use List::MoreUtils qw(any);

=head1 NAME

FixMyStreet::App::Controller::Around - Catalyst Controller

=head1 DESCRIPTION

Allow the user to search for reports around a particular location.

=head1 METHODS

=head2 around

Find the location search and display nearby reports (for pc or lat,lon).

For x,y searches convert to lat,lon and 301 redirect to them.

If no search redirect back to the homepage.

=cut

sub around_index : Path : Args(0) {
    my ( $self, $c ) = @_;

    # check for x,y requests and redirect them to lat,lon
    my $x = $c->req->param('x');
    my $y = $c->req->param('y');
    if ( $x || $y ) {
        my ( $lat, $lon ) = FixMyStreet::Map::tile_xy_to_wgs84( $x, $y );
        my $ll_uri = $c->uri_for( '/around', { lat => $lat, lon => $lon } );
        $c->res->redirect( $ll_uri, 301 );
        return;
    }

    # if there was no search then redirect to the homepage
    if ( !any { $c->req->param($_) } qw(pc lat lon) ) {
        return $c->res->redirect( $c->uri_for('/') );
    }
    
    
}

__PACKAGE__->meta->make_immutable;

1;
