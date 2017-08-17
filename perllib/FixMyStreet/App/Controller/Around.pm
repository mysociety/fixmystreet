package FixMyStreet::App::Controller::Around;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Map;
use Encode;
use JSON::MaybeXS;
use Utils;

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

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    # handle old coord systems
    $c->forward('redirect_en_or_xy_to_latlon');

    # Check if we have a partial report
    my $partial_report = $c->forward('load_partial');

    # Check if the user is searching for a report by ID
    if ( $c->get_param('pc') && $c->get_param('pc') =~ $c->cobrand->lookup_by_ref_regex ) {
        $c->go('lookup_by_ref', [ $1 ]);
    }

    # Try to create a location for whatever we have
    my $ret = $c->forward('/location/determine_location_from_coords')
        || $c->forward('/location/determine_location_from_pc');
    unless ($ret) {
        return $c->res->redirect('/') unless $c->get_param('pc') || $partial_report;
        return;
    }

    # Check to see if the spot is covered by a area - if not show an error.
    return unless $c->forward('check_location_is_acceptable', []);

    # If we have a partial - redirect to /report/new so that it can be
    # completed.
    if ($partial_report) {
        my $new_uri = $c->uri_for(
            '/report/new',
            {
                partial   => $c->stash->{partial_token}->token,
                latitude  => $c->stash->{latitude},
                longitude => $c->stash->{longitude},
                pc        => $c->stash->{pc},
            }
        );
        return $c->res->redirect($new_uri);
    }

    # Show the nearby reports
    $c->detach('display_location');
}

=head2 redirect_en_or_xy_to_latlon

    # detaches if there was a redirect
    $c->forward('redirect_en_or_xy_to_latlon');

Handle coord systems that are no longer in use.

=cut

sub redirect_en_or_xy_to_latlon : Private {
    my ( $self, $c ) = @_;

    # check for x,y or e,n requests
    my $x = $c->get_param('x');
    my $y = $c->get_param('y');
    my $e = $c->get_param('e');
    my $n = $c->get_param('n');

    # lat and lon - fill in below if we need to
    my ( $lat, $lon );

    if ( $x || $y ) {
        ( $lat, $lon ) = FixMyStreet::Map::tile_xy_to_wgs84( $x, $y );
        ( $lat, $lon ) = map { Utils::truncate_coordinate($_) } ( $lat, $lon );
    }
    elsif ( $e || $n ) {
        ( $lat, $lon ) = Utils::convert_en_to_latlon_truncated( $e, $n );
    }
    else {
        return;
    }

    # create a uri and redirect to it
    my $ll_uri = $c->uri_for( '/around', { lat => $lat, lon => $lon } );
    $c->res->redirect( $ll_uri, 301 );
    $c->detach;
}

=head2 load_partial

    my $partial_report = $c->forward('load_partial');

Check for the partial token and load the partial report. If found save it and
token to stash and return report. Otherwise return false.

=cut

sub load_partial : Private {
    my ( $self, $c ) = @_;

    my $partial = $c->get_param('partial')
      || return;

    # is it in the database
    my $token =
      $c->model("DB::Token")
      ->find( { scope => 'partial', token => $partial } )    #
      || last;

    # can we get an id from it?
    my $report_id = $token->data                             #
      || last;

    # load the related problem
    my $report = $c->cobrand->problems                       #
      ->search( { id => $report_id, state => 'partial' } )   #
      ->first
      || last;

    # save what we found on the stash.
    $c->stash->{partial_token}  = $token;
    $c->stash->{partial_report} = $report;

    return $report;
}

=head2 display_location

Display a specific lat/lng location (which may have come from a pc search).

=cut

sub display_location : Private {
    my ( $self, $c ) = @_;

    # set the template to use
    $c->stash->{template} = 'around/display_location.html';

    $c->forward('/auth/get_csrf_token');

    # Check the category to filter by, if any, is valid
    $c->forward('check_and_stash_category');

    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    $c->forward('map_features', [ { latitude => $latitude, longitude => $longitude } ] );

    FixMyStreet::Map::display_map(
        $c,
        latitude  => $latitude,
        longitude => $longitude,
        clickable => 1,
        pins      => $c->stash->{pins},
        area      => $c->cobrand->areas_on_around,
    );

    return 1;
}

=head2 check_location_is_acceptable

Find the lat and lon in stash and check that they are acceptable to the area,
and that they are in UK (if we are in UK).

=cut

sub check_location_is_acceptable : Private {
    my ( $self, $c ) = @_;

    # check that there are areas that can accept this location
    $c->stash->{area_check_action} = 'submit_problem';
    $c->stash->{remove_redundant_areas} = 1;
    return $c->forward('/council/load_and_check_areas');
}

=head2 check_and_stash_category

Check that the 'filter_category' query param is valid, if it's present. Stores
the validated string in the stash as filter_category.
Puts all the valid categories in filter_categories on the stash.

=cut

sub check_and_stash_category : Private {
    my ( $self, $c ) = @_;

    my $all_areas = $c->stash->{all_areas};
    my @bodies = $c->model('DB::Body')->search(
        { 'body_areas.area_id' => [ keys %$all_areas ], deleted => 0 },
        { join => 'body_areas' }
    )->all;
    my %bodies = map { $_->id => $_ } @bodies;

    my @contacts = $c->model('DB::Contact')->not_deleted->search(
        {
            body_id => [ keys %bodies ],
        },
        {
            columns => [ 'category' ],
            order_by => [ 'category' ],
            distinct => 1
        }
    )->all;
    my @categories = map { { name => $_->category, value => $_->category_display } } @contacts;
    $c->stash->{filter_categories} = \@categories;
    my %categories_mapped = map { $_ => 1 } @categories;

    my $categories = [ $c->get_param_list('filter_category', 1) ];
    my %valid_categories = map { $_ => 1 } grep { $_ && $categories_mapped{$_} } @$categories;
    $c->stash->{filter_category} = \%valid_categories;
}

sub map_features : Private {
    my ($self, $c, $extra) = @_;

    $c->stash->{page} = 'around'; # Needed by _item.html / so the map knows to make clickable pins, update on pan

    $c->forward( '/reports/stash_report_filter_status' );
    $c->forward( '/reports/stash_report_sort', [ 'created-desc' ]);

    # Deal with pin hiding/age
    my $all_pins = $c->get_param('all_pins') ? 1 : undef;
    $c->stash->{all_pins} = $all_pins;
    my $interval = $all_pins ? undef : $c->cobrand->on_map_default_max_pin_age;

    return if $c->get_param('js'); # JS will request the same (or more) data client side

    my ( $on_map_all, $on_map_list, $nearby, $distance ) =
      FixMyStreet::Map::map_features(
        $c, interval => $interval, %$extra,
        categories => [ keys %{$c->stash->{filter_category}} ],
        states => $c->stash->{filter_problem_states},
        order => $c->stash->{sort_order},
      );

    my @pins;
    unless ($c->get_param('no_pins')) {
        @pins = map {
            # Here we might have a DB::Problem or a DB::Result::Nearby, we always want the problem.
            my $p = (ref $_ eq 'FixMyStreet::DB::Result::Nearby') ? $_->problem : $_;
            $p->pin_data($c, 'around');
        } @$on_map_all, @$nearby;
    }

    $c->stash->{pins} = \@pins;
    $c->stash->{on_map} = $on_map_list;
    $c->stash->{around_map} = $nearby;
    $c->stash->{distance} = $distance;
}

=head2 /ajax

Handle the ajax calls that the map makes when it is dragged. The info returned
is used to update the pins on the map and the text descriptions on the side of
the map.

=cut

sub ajax : Path('/ajax') {
    my ( $self, $c ) = @_;

    my $bbox = $c->get_param('bbox');
    unless ($bbox) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }

    my %valid_categories = map { $_ => 1 } $c->get_param_list('filter_category', 1);
    $c->stash->{filter_category} = \%valid_categories;

    $c->forward('map_features', [ { bbox => $bbox } ]);
    $c->forward('/reports/ajax', [ 'around/on_map_list_items.html' ]);
}

sub location_autocomplete : Path('/ajax/geocode') {
    my ( $self, $c ) = @_;
    $c->res->content_type('application/json; charset=utf-8');
    unless ( $c->get_param('term') ) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }
    # we want the match even if there's no ambiguity, so recommendation doesn't
    # disappear when it's the last choice being offered in the autocomplete.
    $c->stash->{allow_single_geocode_match_strings} = 1;
    return $self->_geocode( $c, $c->get_param('term') );
}

sub location_lookup : Path('/ajax/lookup_location') {
    my ( $self, $c ) = @_;
    $c->res->content_type('application/json; charset=utf-8');
    unless ( $c->get_param('term') ) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }

    return $self->_geocode( $c, $c->get_param('term') );
}

sub _geocode : Private {
    my ( $self, $c, $term ) = @_;

    my ( $lat, $long, $suggestions ) =
        FixMyStreet::Geocode::lookup( $c->get_param('term'), $c );

    my ($response, @addresses, @locations);

    if ( $lat && $long ) {
        $response = { latitude => $lat, longitude => $long };
    } else {
        if ( ref($suggestions) eq 'ARRAY' ) {
            foreach (@$suggestions) {
                my $address = $_->{address};
                $address = decode_utf8($address) if !utf8::is_utf8($address);
                push @addresses, $address;
                push @locations, { address => $address, lat => $_->{latitude}, long => $_->{longitude} };
            }
            $response = { suggestions => \@addresses, locations => \@locations };
        } else {
            $response = { error => $suggestions };
        }
    }

    if ( $c->stash->{allow_single_geocode_match_strings} ) {
        $response = \@addresses;
    }

    my $body = encode_json($response);
    $c->res->body($body);

}

sub lookup_by_ref : Private {
    my ( $self, $c, $ref ) = @_;

    my $problems = $c->cobrand->problems->search([
        id => $ref,
        external_id => $ref
    ]);

    if ( $problems->count == 0) {
        $c->detach( '/page_error_404_not_found', [] );
    } elsif ( $problems->count == 1 ) {
        $c->res->redirect( $c->uri_for( '/report', $problems->first->id ) );
    } else {
        $c->stash->{ref} = $ref;
        $c->stash->{matching_reports} = [ $problems->all ];
    }
}

__PACKAGE__->meta->make_immutable;

1;
