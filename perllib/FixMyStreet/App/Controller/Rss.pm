package FixMyStreet::App::Controller::Rss;

use Moose;
use namespace::autoclean;
use URI::Escape;
use FixMyStreet::Alert;
use mySociety::Gaze;
use mySociety::Locale;
use mySociety::MaPit;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Rss - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub updates : LocalRegex('^(\d+)$') {
    my ( $self, $c ) = @_;

    my $id = $c->req->captures->[0];
    my $problem = $c->model('DB::Problem')->find( { id => $id } );

    # FIXME Put these 404/410 checks in central place - Report.pm does it too.
    if ( !$problem || $problem->state eq 'unconfirmed' ) {
        $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] );
    } elsif ( $problem->state eq 'hidden' ) {
        $c->detach(
            '/page_error_410_gone',
            [ _('That report has been removed from FixMyStreet.') ]
        );
    }

    $c->stash->{type}      = 'new_updates';
    $c->stash->{qs}        = 'report/' . $id;
    $c->stash->{db_params} = [ $id ];
    $c->forward('output');
}

sub new_problems : Path('problems') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{type} = 'new_problems';
    $c->forward('output');
}

# FIXME I don't think this is used - check
#sub reports_to_council : Private {
#    my ( $self, $c ) = @_;
#
#    my $id                 = $c->stash->{id};
#    $c->stash->{type}      = 'council_problems';
#    $c->stash->{qs}        = '/' . $id;
#    $c->stash->{db_params} = [ $id ];
#    $c->forward('output');
#}

sub reports_in_area : LocalRegex('^area/(\d+)$') {
    my ( $self, $c ) = @_;

    my $id                    = $c->req->captures->[0];
    my $area                  = mySociety::MaPit::call('area', $id);
    $c->stash->{type}         = 'area_problems';
    $c->stash->{qs}           = '/' . $id;
    $c->stash->{db_params}    = [ $id ];
    $c->stash->{title_params} = { NAME => $area->{name} };
    $c->forward('output');
}

sub all_problems : Private {
    my ( $self, $c ) = @_;

    $c->stash->{type} = 'all_problems';
    $c->forward('output');
}

sub local_problems_pc : Path('pc') : Args(1) {
    my ( $self, $c, $query ) = @_;
    $c->forward( 'local_problems_pc_distance', [ $query ] );
}

sub local_problems_pc_distance : Path('pc') : Args(2) {
    my ( $self, $c, $query, $d ) = @_;

    $c->forward( 'get_query_parameters', [ $d ] );
    unless ( $c->forward( '/location/determine_location_from_pc', [ $query ] ) ) {
        $c->res->redirect( '/alert' );
        $c->detach();
    }

    my $pretty_query = $query;
    $pretty_query = mySociety::PostcodeUtil::canonicalise_postcode($query)
        if mySociety::PostcodeUtil::is_valid_postcode($query);

    my $pretty_query_escaped = URI::Escape::uri_escape_utf8($pretty_query);
    $pretty_query_escaped =~ s/%20/+/g;

    $c->stash->{qs}           = "?pc=$pretty_query_escaped";
    $c->stash->{title_params} = { POSTCODE => $pretty_query };
    $c->stash->{type}         = 'postcode_local_problems';

    $c->forward( 'local_problems_ll',
      [ $c->stash->{latitude}, $c->stash->{longitude} ]
    );

}

sub local_problems : LocalRegex('^(n|l)/([\d.-]+)[,/]([\d.-]+)(?:/(\d+))?$') {
    my ( $self, $c ) = @_;

    my ( $type, $a, $b, $d) = @{ $c->req->captures };
    $c->forward( 'get_query_parameters', [ $d ] );

    $c->detach( 'redirect_lat_lon', [ $a, $b ] )
        if $type eq 'n';

    $c->stash->{qs}   = "?lat=$a;lon=$b";
    $c->stash->{type} = 'local_problems';

    $c->forward( 'local_problems_ll', [ $a, $b ] );
}

sub local_problems_ll : Private {
    my ( $self, $c, $lat, $lon ) = @_;

    # truncate the lat,lon for nicer urls
    ( $lat, $lon ) = map { Utils::truncate_coordinate($_) } ( $lat, $lon );    
    
    my $d = $c->stash->{distance};
    if ( $d ) {
        $c->stash->{qs} .= ";d=$d";
        $d = 100 if $d > 100;
    } else {
        $d = mySociety::Gaze::get_radius_containing_population( $lat, $lon, 200000 );
        $d = int( $d * 10 + 0.5 ) / 10;
        mySociety::Locale::in_gb_locale {
            $d = sprintf("%f", $d);
        }
    }

    $c->stash->{db_params} = [ $lat, $lon, $d ];

    if ($c->stash->{state} ne 'all') {
        $c->stash->{type} .= '_state';
        push @{ $c->stash->{db_params} }, $c->stash->{state};
    }
    
    $c->forward('output');
}

sub output : Private {
    my ( $self, $c ) = @_;
    $c->response->header('Content-Type' => 'application/xml; charset=utf-8');
    $c->response->body( FixMyStreet::Alert::generate_rss( $c ) );
}

sub local_problems_legacy : LocalRegex('^(\d+)[,/](\d+)(?:/(\d+))?$') {
    my ( $self, $c ) = @_;
    my ($x, $y, $d) = @{ $c->req->captures };
    $c->forward( 'get_query_parameters', [ $d ] );

    # 5000/31 as initial scale factor for these RSS feeds, now variable so redirect.
    my $e = int( ($x * 5000/31) + 0.5 );
    my $n = int( ($y * 5000/31) + 0.5 );
    $c->detach( 'redirect_lat_lon', [ $e, $n ] );
}

sub get_query_parameters : Private {
    my ( $self, $c, $d ) = @_;

    $d = '' unless $d =~ /^\d+$/;
    $c->stash->{distance} = $d;

    my $state = $c->req->param('state') || 'all';
    $state = 'all' unless $state =~ /^(all|open|fixed)$/;
    $c->stash->{state_qs} = "?state=$state" unless $state eq 'all';

    $state = 'confirmed' if $state eq 'open';
    $c->stash->{state} = $state;
}

sub redirect_lat_lon : Private {
    my ( $self, $c, $e, $n ) = @_;
    my ($lat, $lon) = Utils::convert_en_to_latlon_truncated($e, $n);

    my $d_str = '';
    $d_str    = '/' . $c->stash->{distance} if $c->stash->{distance};
    $c->res->redirect( "/rss/l/$lat,$lon" . $d_str . $c->stash->{state_qs} );
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;
