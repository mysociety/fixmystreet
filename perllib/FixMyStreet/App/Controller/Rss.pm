package FixMyStreet::App::Controller::Rss;

use Moose;
use namespace::autoclean;
use POSIX qw(strftime);
use URI::Escape;
use XML::RSS;

use mySociety::Gaze;
use mySociety::Locale;
use mySociety::MaPit;
use mySociety::Sundries qw(ordinal);
use mySociety::Web qw(ent);

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
    $c->forward( '/report/load_problem_or_display_error', [ $id ] );

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

    $c->stash->{alert_type} = $c->model('DB::AlertType')->find( { ref => $c->stash->{type} } );
    $c->detach( '/page_error_404_not_found', [ _('Unknown alert type') ] )
        unless $c->stash->{alert_type};

    $c->forward( 'query_main' );

    # Do our own encoding
    $c->stash->{rss} = new XML::RSS(
        version       => '2.0',
        encoding      => 'UTF-8',
        stylesheet    => $c->cobrand->feed_xsl,
        encode_output => undef
    );
    $c->stash->{rss}->add_module(
        prefix => 'georss',
        uri    => 'http://www.georss.org/georss'
    );

    while (my $row = $c->stash->{query_main}->fetchrow_hashref) {
        $c->forward( 'add_row', [ $row ] );
    }

    $c->forward( 'add_parameters' );

    my $out = $c->stash->{rss}->as_string;
    my $uri = $c->uri_for( '/' . $c->req->path );
    $out =~ s{<link>(.*?)</link>}{"<link>" . $c->uri_for( $1 ) . "</link><uri>$uri</uri>"}e;

    $c->response->header('Content-Type' => 'application/xml; charset=utf-8');
    $c->response->body( $out );
}

sub query_main : Private {
    my ( $self, $c ) = @_;
    my $alert_type = $c->stash->{alert_type};

    my ( $site_restriction, $site_id ) = $c->cobrand->site_restriction( $c->cobrand->extra_data );
    # Only apply a site restriction if the alert uses the problem table
    $site_restriction = '' unless $alert_type->item_table eq 'problem';

    # FIXME Do this in a nicer way at some point in the future...
    my $query = 'select * from ' . $alert_type->item_table . ' where '
        . ($alert_type->head_table ? $alert_type->head_table . '_id=? and ' : '')
        . $alert_type->item_where . $site_restriction . ' order by '
        . $alert_type->item_order;
    my $rss_limit = mySociety::Config::get('RSS_LIMIT');
    $query .= " limit $rss_limit" unless $c->stash->{type} =~ /^all/;

    my $q = $c->model('DB::Alert')->result_source->storage->dbh->prepare($query);

    $c->stash->{db_params} ||= [];
    if ($query =~ /\?/) {
        $c->detach( '/page_error_404_not_found', [ 'Missing parameter' ] )
            unless @{ $c->stash->{db_params} };
        $q->execute( @{ $c->stash->{db_params} } );
    } else {
        $q->execute();
    }
    $c->stash->{query_main} = $q;
}

sub add_row : Private {
    my ( $self, $c, $row ) = @_;
    my $alert_type = $c->stash->{alert_type};

    $row->{name} ||= 'anonymous';

    my $pubDate;
    if ($row->{confirmed}) {
        $row->{confirmed} =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
        $pubDate = mySociety::Locale::in_gb_locale {
            strftime("%a, %d %b %Y %H:%M:%S %z", $6, $5, $4, $3, $2-1, $1-1900, -1, -1, 0)
        };
        $row->{confirmed} = strftime("%e %B", $6, $5, $4, $3, $2-1, $1-1900, -1, -1, 0);
        $row->{confirmed} =~ s/^\s+//;
        $row->{confirmed} =~ s/^(\d+)/ordinal($1)/e if $c->stash->{lang_code} eq 'en-gb';
    }

    (my $title = _($alert_type->item_title)) =~ s/{{(.*?)}}/$row->{$1}/g;
    (my $link = $alert_type->item_link) =~ s/{{(.*?)}}/$row->{$1}/g;
    (my $desc = _($alert_type->item_description)) =~ s/{{(.*?)}}/$row->{$1}/g;
    my $url = $c->uri_for( $link );
    my %item = (
        title => ent($title),
        link => $url,
        guid => $url,
        description => ent(ent($desc)) # Yes, double-encoded, really.
    );
    $item{pubDate} = $pubDate if $pubDate;
    $item{category} = $row->{category} if $row->{category};

    if ($c->cobrand->allow_photo_display && $row->{photo}) {
        my $key = $alert_type->item_table eq 'comment' ? 'c' : 'id';
        $item{description} .= ent("\n<br><img src=\"". $c->cobrand->base_url . "/photo?$key=$row->{id}\">");
    }
    my $recipient_name = $c->cobrand->contact_name;
    $item{description} .= ent("\n<br><a href='$url'>" .
        sprintf(_("Report on %s"), $recipient_name) . "</a>");

    if ($row->{latitude} || $row->{longitude}) {
        $item{georss} = { point => "$row->{latitude} $row->{longitude}" };
    }

    $c->stash->{rss}->add_item( %item );
}

sub add_parameters : Private {
    my ( $self, $c ) = @_;
    my $alert_type = $c->stash->{alert_type};

    my $row = {};
    if ($alert_type->head_sql_query) {
        my $q = $c->model('DB::Alert')->result_source->storage->dbh->prepare(
            $alert_type->head_sql_query
        );
        if ($alert_type->head_sql_query =~ /\?/) {
            $q->execute(@{ $c->stash->{db_params} });
        } else {
            $q->execute();
        }
        $row = $q->fetchrow_hashref;
    }
    foreach ( keys %{ $c->stash->{title_params} } ) {
        $row->{$_} = $c->stash->{title_params}->{$_};
    }

    (my $title = _($alert_type->head_title)) =~ s/{{(.*?)}}/$row->{$1}/g;
    (my $link = $alert_type->head_link) =~ s/{{(.*?)}}/$row->{$1}/g;
    (my $desc = _($alert_type->head_description)) =~ s/{{(.*?)}}/$row->{$1}/g;

    $c->stash->{rss}->channel(
        title       => ent($title),
        link        => $link . ($c->stash->{qs} || ''),
        description => ent($desc),
        language    => 'en-gb',
    );
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

    $d = '' unless $d && $d =~ /^\d+$/;
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
    my $state_qs = '';
    $state_qs    = $c->stash->{state_qs} if $c->stash->{state_qs};
    $c->res->redirect( "/rss/l/$lat,$lon" . $d_str . $state_qs );
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;
