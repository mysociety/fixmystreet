package FixMyStreet::App::Controller::Around;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Geocode::Address;
use FixMyStreet::Map;
use Encode;
use JSON::MaybeXS;
use Utils;
use Try::Tiny;
use Text::CSV;

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

    if ($c->get_param('ajax')) {
        $c->detach('ajax');
    }

    # Check if the user is searching for a report by ID
    if ( $c->get_param('pc') && $c->get_param('pc') =~ $c->cobrand->lookup_by_ref_regex ) {
        $c->go('lookup_by_ref', [ $1 ]);
    }

    # handle old coord systems
    $c->forward('redirect_en_or_xy_to_latlon');

    # Check if we have a partial report
    my $partial_report = $c->forward('load_partial');

    # Check if we have a photo
    my $photo_info = $c->forward('load_photo');

    # Try to create a location for whatever we have
    my $ret = $c->forward('/location/determine_location_from_bbox')
        || $c->forward('/location/determine_location_from_coords')
        || $c->forward('/location/determine_location_from_pc');
    unless ($ret) {
        return $c->res->redirect('/') unless $c->get_param('pc') || $partial_report || $photo_info;
        # Cobrand may want to perform custom searching at this point,
        # e.g. presenting a list of reports matching the user's query.
        $c->cobrand->call_hook("around_custom_search");
        return;
    }

    # Check to see if the spot is covered by a area - if not show an error.
    return unless $c->forward('check_location_is_acceptable', []);

    # Redirect to /report/new in four cases:
    #  - if we have a partial report, so that it can be completed.
    #  - if the cobrand doesn't show anything on /around (e.g. a private
    #    reporting site)
    #  - if we are setting the location for an offline draft.
    #  - if we have a photo from the front page upload.
    my $draft = $c->get_param('setDraftLocation');
    if ($partial_report || $c->cobrand->call_hook("skip_around_page") || defined($draft) || $photo_info) {
        my $params = {
            latitude  => $c->stash->{latitude},
            longitude => $c->stash->{longitude},
            pc        => $c->stash->{pc}
        };
        if (defined($draft)) {
            # Tells the frontend JS to use the given offline draft.
            $params->{restoreDraft} = $draft;
        }
        if ($partial_report) {
            $params->{partial} = $c->stash->{partial_token}->token;
        } elsif ($photo_info) {
            $params->{photo_id} = $c->stash->{photo_id};
        } elsif ($c->get_param("category")) {
            $params->{category} = $c->get_param("category");
        }
        my $new_uri = $c->uri_for('/report/new', $params);
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

=head2 load_photo

    my $photo_info = $c->forward('load_photo');

Check for the photo_id parameter and validate it exists in storage.
If found, save photo_id to stash and return true. Otherwise return false.

=cut

sub load_photo : Private {
    my ( $self, $c ) = @_;

    my $photo_id = $c->get_param('photo_id')
      || return;

    # Validate the photo exists in storage
    my $photoset = FixMyStreet::App::Model::PhotoSet->new({
        data_items => [ $photo_id ]
    });

    # Check if photo_id is valid (has at least one image)
    return unless $photoset->num_images > 0;

    # Save to stash for templates
    $c->stash->{photo_id} = $photo_id;

    return 1;
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

    if (my $bbox = $c->stash->{bbox}) {
        $c->forward('map_features', [ { bbox => $bbox } ]);
    } else {
        $c->forward('map_features', [ { latitude => $latitude, longitude => $longitude } ]);
    }

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
    my ( $self, $c, $prefetched_all_areas ) = @_;

    # check that there are areas that can accept this location
    $c->stash->{area_check_action} = 'submit_problem';
    $c->stash->{remove_redundant_areas} = 1;
    return $c->forward('/council/load_and_check_areas', [ $prefetched_all_areas ]);
}

=head2 check_and_stash_category

Check that the 'filter_category' query param is valid, if it's present. Stores
the validated string in the stash as filter_category.
Puts all the valid categories in filter_categories on the stash.

=cut

sub check_and_stash_category : Private {
    my ( $self, $c ) = @_;

    my $all_areas = $c->stash->{all_areas};
    my @bodies = $c->model('DB::Body')->active->for_areas(keys %$all_areas)->all;
    my %bodies = map { $_->id => $_ } @bodies;
    $c->cobrand->call_hook(munge_report_new_bodies => \%bodies); # To match setup_categories_and_bodies in New.pm

    my @list_of_names = map { $_->name } values %bodies;
    my $csv = Text::CSV->new();
    $csv->combine(@list_of_names);
    $c->stash->{around_bodies} = \@bodies;
    $c->stash->{bodies_ids} = [ map { $_->id } @bodies];
    $c->{stash}->{list_of_names_as_string} = $csv->string;

    my $where = { body_id => [ keys %bodies ], };
    $c->cobrand->call_hook('munge_around_category_where', $where);

    my $rs = $c->model('DB::Contact');
    if ($c->user_exists) {
        if ($c->user->is_superuser) {
            $rs = $rs->not_deleted_admin;
        } elsif ($c->user->has_body_permission_to('report_inspect') ||
                 $c->user->has_body_permission_to('report_mark_private')) {
            $where = {
                -or => [
                    {
                        body_id => [ keys %bodies ],
                        state => { -not_in => [ "deleted", "staff" ] },
                    },
                    {
                        body_id => $c->user->from_body->id,
                        state => { -not_in => [ "deleted" ] },
                    }
                ],
            };
        } else {
            $rs = $rs->not_deleted;
        }
    } else {
        $rs = $rs->not_deleted;
    }
    my @categories = $rs->search(
        $where,
        {
            columns => [ 'id', 'category', 'extra' ],
            distinct => 1
        }
    )->all_sorted;
    # Ensure only uniquely named categories are shown
    my %seen;
    my %filter_id;
    my $group;
    for my $category (@categories) {
        next unless $category->category_display;
        if ($category->extra->{group}) {
            $group = $category->extra->{group};
            if (ref $group ne 'ARRAY') {
                $group = [$group];
            }
        } else {
            $group = ['no_group'];
        }
        for my $group_name (@$group) {
            $seen{$group_name}->{$category->category_display}++;
            if ($seen{$group_name}{$category->category_display} > 1) {
                my $id = $category->id;
                $filter_id{$id} = 1
            }
        }
    };

    @categories = grep { !$filter_id{$_->id} } @categories;
    $c->stash->{filter_categories} = \@categories;
    my %categories_mapped = map { $_->category => 1 } @categories;
    $c->forward('/report/stash_category_groups', [ \@categories ]);

    my $categories = [ $c->get_param_list('filter_category', 1) ];
    my %valid_categories = map { $_ => 1 } grep { $_ && $categories_mapped{$_} } @$categories;
    $c->stash->{filter_category} = \%valid_categories;
    $c->cobrand->call_hook('munge_around_filter_category_list');

    $c->forward('/report/assigned_users_only', [ \@categories ]);
}

sub map_features : Private {
    my ($self, $c, $extra) = @_;

    $c->stash->{page} = 'around'; # Needed by _item.html / so the map knows to make clickable pins, update on pan
    $c->stash->{num_old_reports} = 0;

    $c->forward( '/reports/stash_report_filter_status' );
    $c->forward( '/reports/stash_report_sort', [ 'created-desc' ]);
    $c->stash->{show_old_reports} = $c->get_param('show_old_reports');

    return if $c->get_param('js'); # JS will request the same (or more) data client side

    my ( $on_map, $nearby, $distance ) =
      FixMyStreet::Map::map_features(
        $c, %$extra,
        categories => [ keys %{$c->stash->{filter_category}} ],
        states => $c->stash->{filter_problem_states},
        order => $c->stash->{sort_order},
      );

    my @pins;
    my $extra_pins;
    unless ($c->get_param('no_pins')) {
        @pins = map {
            # Here we might have a DB::Problem or a DB::Result::Nearby, we always want the problem.
            my $p = (ref $_ eq 'FixMyStreet::DB::Result::Nearby') ? $_->problem : $_;
            $p->pin_data('around');
        } @$on_map, @$nearby;

        $extra_pins = $c->cobrand->call_hook('extra_around_pins', $extra->{bbox});
        @pins = (@pins, @$extra_pins) if $extra_pins;
    }

    $c->stash->{pins} = \@pins;
    $c->stash->{extra_pins} = $extra_pins;
    $c->stash->{on_map} = $on_map;
    $c->stash->{around_map} = $nearby;
    $c->stash->{distance} = $distance if $distance; # So Gaze not called again
}

=head2 ajax

Handle the ajax calls that the map makes when it is dragged. The info returned
is used to update the pins on the map and the text descriptions on the side of
the map. Used via /around?ajax=1 but also available at /ajax for mobile app.

=cut

sub ajax : Path('/ajax') {
    my ( $self, $c ) = @_;

    $c->forward('/set_app_cors_header');
    my $ret = $c->forward('/location/determine_location_from_bbox');
    unless ($ret) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }

    my %valid_categories = map { $_ => 1 } $c->get_param_list('filter_category', 1);
    $c->stash->{filter_category} = \%valid_categories;
    $c->cobrand->call_hook('munge_around_filter_category_list');

    $c->forward('map_features', [ { bbox => $c->stash->{bbox} } ]);
    $c->forward('/reports/ajax', [ 'around/on_map_list_items.html' ]);
}

sub nearby : Path {
    my ($self, $c) = @_;

    my $states = FixMyStreet::DB::Result::Problem->open_states();
    my $params = {
        latitude => $c->get_param('latitude'),
        longitude => $c->get_param('longitude'),
        categories => [ $c->get_param('filter_category') || () ],
        group => $c->get_param('filter_group'),
        states => $states,
        bodies => $c->get_param('bodies'),
    };
    $c->cobrand->call_hook('around_nearby_filter', $params);
    $c->forward('/report/_nearby_json', [ $params ]);
}

sub location_closest_address : Path('/ajax/closest') {
    my ( $self, $c ) = @_;
    $c->res->content_type('application/json; charset=utf-8');

    my $lat = $c->get_param('lat');
    my $lon = $c->get_param('lon');
    unless ($lat && $lon) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }

    my $closest = $c->cobrand->find_closest({ latitude => $lat, longitude => $lon });
    my $data = $closest->for_around;
    $c->res->body(encode_json($data));
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
    $c->forward('/set_app_cors_header');
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
                push @addresses, $_->{address};
                push @locations, { address => $_->{address}, lat => $_->{latitude}, long => $_->{longitude} };
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

    my $criteria = $c->cobrand->call_hook("lookup_by_ref", $ref) ||
        [
            id => $ref,
            external_id => $ref
        ];

    my $params = {};
    my $rs = $c->cobrand->problems;

    $rs->non_public_if_possible($params, $c);
    push @{ $params->{-and} }, { -or => $criteria };

    my $problems = $rs->search($params);

    my $count = try {
        $problems->count;
    } catch {
        0;
    };

    if ($count > 1) {
        $c->stash->{ref} = $ref;
        $c->stash->{matching_reports} = [ $problems->all ];
    } elsif ($count == 1) {
        $c->res->redirect( $c->uri_for( '/report', $problems->first->id ) );
    }
}

__PACKAGE__->meta->make_immutable;

1;
