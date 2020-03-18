package FixMyStreet::Cobrand::UK;
use base 'FixMyStreet::Cobrand::Default';
use strict;

use JSON::MaybeXS;
use mySociety::MaPit;
use mySociety::VotingArea;
use Utils;
use HighwaysEngland;

sub country             { return 'GB'; }
sub area_types          { [ 'DIS', 'LBO', 'MTD', 'UTA', 'CTY', 'COI', 'LGD' ] }
sub area_types_children { $mySociety::VotingArea::council_child_types }

sub csp_config {
    my $self = shift;
    return $self->feature('content_security_policy');
}

sub enter_postcode_text {
    my ( $self ) = @_;
    return _("Enter a nearby UK postcode, or street name and area");
}

sub example_places {
    return [ 'B2 4QA', 'Tib St, Manchester' ];
}

sub disambiguate_location {
    return {
        country => 'gb',
        google_country => 'uk',
        bing_culture => 'en-GB',
        bing_country => 'United Kingdom'
    };
}

sub process_open311_extras {
    my $self    = shift;
    my $ctx     = shift;
    my $body = shift;
    my $extra   = shift;
    my $fields  = shift || [];

    if ( $body && $body->name =~ /Bromley/ ) {
        my @fields = ( 'fms_extra_title', @$fields );
        for my $field ( @fields ) {
            my $value = $ctx->get_param($field);

            if ( !$value ) {
                $ctx->stash->{field_errors}->{ $field } = _('This information is required');
            }
            push @$extra, {
                name => $field,
                description => uc( $field),
                value => $value || '',
            };
        }

        if ( $ctx->get_param('fms_extra_title') ) {
            $ctx->stash->{fms_extra_title} = $ctx->get_param('fms_extra_title');
            $ctx->stash->{extra_name_info} = 1;
        }
    }
}

sub geocode_postcode {
    my ( $self, $s ) = @_;

    if ($s =~ /^\d+$/) {
        return {
            error => 'FixMyStreet is a UK-based website. Please enter either a UK postcode, or street name and area.'
        };
    } elsif (mySociety::PostcodeUtil::is_valid_postcode($s)) {
        my $location = mySociety::MaPit::call('postcode', $s);
        if ($location->{error}) {
            return {
                error => $location->{code} =~ /^4/
                    ? _('That postcode was not recognised, sorry.')
                    : $location->{error}
            };
        }
        my $island = $location->{coordsyst};
        if (!$island) {
            return {
                error => _("Sorry, that appears to be a Crown dependency postcode, which we don't cover.")
            };
        }
        return {
            latitude  => $location->{wgs84_lat},
            longitude => $location->{wgs84_lon},
        };
    } elsif (my $junction_location = HighwaysEngland::junction_lookup($s)) {
        return $junction_location;
    }
    return {};
}

sub short_name {
    my $self = shift;
    my ($area) = @_;

    my $name = $area->{name} || $area->name;

    # Special case Durham as it's the only place with two councils of the same name
    return 'Durham+County' if $name eq 'Durham County Council';
    return 'Durham+City' if $name eq 'Durham City Council';

    $name =~ s/^(Royal|London) Borough of //;
    $name =~ s/ (Borough|City|District|County) Council$//;
    $name =~ s/ Council$//;
    $name =~ s/ & / and /;
    $name =~ tr{/}{_};
    $name = URI::Escape::uri_escape_utf8($name);
    $name =~ s/%20/+/g;
    return $name;
}

sub find_closest {
    my ($self, $data) = @_;

    $data = { problem => $data } if ref $data ne 'HASH';

    my $problem = $data->{problem};
    my $lat = $problem ? $problem->latitude : $data->{latitude};
    my $lon = $problem ? $problem->longitude : $data->{longitude};

    my $closest = $self->SUPER::find_closest($data);

    ($lat, $lon) = map { Utils::truncate_coordinate($_) } $lat, $lon;
    my $j = mySociety::MaPit::call('nearest', "4326/$lon,$lat");
    if ($j->{postcode}) {
        $closest->{postcode} = $j->{postcode};
    }

    return $closest;
}

sub reports_body_check {
    my ( $self, $c, $code ) = @_;

    # Deal with Bexley and Greenwich name not starting with short name
    if ($code =~ /bexley|greenwich/i) {
        my $body = $c->model('DB::Body')->search( { name => { -like => "%$code%" } } )->single;
        $c->stash->{body} = $body;
        return $body;
    }

    # Manual misspelling redirect
    if ($code =~ /^rhondda cynon taff$/i) {
        my $url = $c->uri_for( '/reports/Rhondda+Cynon+Taf' );
        $c->res->redirect( $url );
        $c->detach();
    }

    # Old ONS codes
    if ($code =~ /^(\d\d)([a-z]{2})?([a-z]{2})?$/i) {
        my $area = mySociety::MaPit::call( 'area', uc $code );
        $c->detach( 'redirect_index' ) if $area->{error}; # Given a bad/old ONS code
        if (length($code) == 6) {
            my $council = mySociety::MaPit::call( 'area', $area->{parent_area} );
            $c->stash->{ward} = $area;
            $c->stash->{body} = $council;
        } else {
            $c->stash->{body} = $area;
        }
        $c->detach( 'redirect_body' );
    }

    # New ONS codes
    if ($code =~ /^[ESWN]\d{8}$/i) {
        my $area = mySociety::MaPit::call( 'area', uc $code );
        $c->detach( 'redirect_index' ) if $area->{error}; # Given a bad/old ONS code
        if ($code =~ /^(E05|W05|S13)/) {
            my $council = mySociety::MaPit::call( 'area', $area->{parent_area} );
            $c->stash->{ward} = $area;
            $c->stash->{body} = $council;
            $c->detach( 'redirect_body' );
        } elsif ($code =~ /^(W06|S12|E0[6-9]|E10)/) {
            $c->stash->{body} = $area;
            $c->detach( 'redirect_body' );
        }
    }

    return;
}

sub council_rss_alert_options {
    my $self = shift;
    my $all_areas = shift;
    my $c = shift;

    my %councils = map { $_ => 1 } @{$self->area_types};

    my $num_councils = scalar keys %$all_areas;

    my ( @options, @reported_to_options );
    if ( $num_councils == 1 or $num_councils == 2 ) {
        my ($council, $ward);
        my $body = FixMyStreet::DB->resultset('Body')->active->search({ name => { '!=' => 'TfL' } })->for_areas(keys %$all_areas)->first;
        foreach (values %$all_areas) {
            if ($councils{$_->{type}}) {
                $council = $_;
                $council->{id} = $body->id; # Want to use body ID, not MapIt area ID
                $council->{short_name} = $self->short_name( $council );
                ( $council->{id_name} = $council->{short_name} ) =~ tr/+/_/;
            } else {
                $ward = $_;
                $ward->{short_name} = $self->short_name( $ward );
                ( $ward->{id_name} = $ward->{short_name} ) =~ tr/+/_/;
            }
        }
        $council->{name} = 'London Borough of Bromley'
            if $council->{name} eq 'Bromley Council';

        my $council_text;
        if ( $c->cobrand->is_council ) {
            $council_text = 'All problems within the council';
        } else {
            $council_text = sprintf( _('Problems within %s'), $council->{name});
        }

        push @options, {
            type      => 'council',
            id        => sprintf( 'council:%s:%s', $council->{id}, $council->{id_name} ),
            text      => $council_text,
            rss_text  => sprintf( _('RSS feed of problems within %s'), $council->{name}),
            uri       => $c->uri_for( '/rss/reports/' . $council->{short_name} ),
        };
        push @options, {
            type     => 'ward',
            id       => sprintf( 'ward:%s:%s:%s:%s', $council->{id}, $ward->{id}, $council->{id_name}, $ward->{id_name} ),
            rss_text => sprintf( _('RSS feed of problems within %s ward'), $ward->{name}),
            text     => sprintf( _('Problems within %s ward'), $ward->{name}),
            uri      => $c->uri_for( '/rss/reports/' . $council->{short_name} . '/' . $ward->{short_name} ),
        } if $ward;

    } elsif ( $num_councils == 4 ) {
        # Two-tier council
        my ($county, $district, $c_ward, $d_ward);
        foreach (values %$all_areas) {
            $_->{short_name} = $self->short_name( $_ );
            ( $_->{id_name} = $_->{short_name} ) =~ tr/+/_/;
            if ($_->{type} eq 'CTY') {
                $county = $_;
            } elsif ($_->{type} eq 'DIS') {
                $district = $_;
            } elsif ($_->{type} eq 'CED') {
                $c_ward = $_;
            } elsif ($_->{type} eq 'DIW') {
                $d_ward = $_;
            }
        }
        my $district_name = $district->{name};
        my $d_ward_name = $d_ward->{name};
        my $county_name = $county->{name};
        my $c_ward_name = $c_ward->{name};

        my $body_dis = FixMyStreet::DB->resultset('Body')->active->for_areas($district->{id})->first;
        my $body_cty = FixMyStreet::DB->resultset('Body')->active->for_areas($county->{id})->first;

        push @options, {
            type  => 'area',
            id    => sprintf( 'area:%s:%s', $district->{id}, $district->{id_name} ),
            text  => sprintf( _('Problems within %s'), $district_name ),
            rss_text => sprintf( _('RSS feed for %s'), $district_name ),
            uri => $c->uri_for( '/rss/area/' . $district->{short_name}  )
        }, {
            type      => 'area',
            id        => sprintf( 'area:%s:%s:%s:%s', $district->{id}, $d_ward->{id}, $district->{id_name}, $d_ward->{id_name} ),
            text      => sprintf( _('Problems within %s ward, %s'), $d_ward_name, $district_name ),
            rss_text  => sprintf( _('RSS feed for %s ward, %s'), $d_ward_name, $district_name ),
            uri       => $c->uri_for( '/rss/area/' . $district->{short_name} . '/' . $d_ward->{short_name} )
        }, {
            type  => 'area',
            id    => sprintf( 'area:%s:%s', $county->{id}, $county->{id_name} ),
            text  => sprintf( _('Problems within %s'), $county_name ),
            rss_text => sprintf( _('RSS feed for %s'), $county_name ),
            uri => $c->uri_for( '/rss/area/' . $county->{short_name}  )
        }, {
            type      => 'area',
            id        => sprintf( 'area:%s:%s:%s:%s', $county->{id}, $c_ward->{id}, $county->{id_name}, $c_ward->{id_name} ),
            text      => sprintf( _('Problems within %s ward, %s'), $c_ward_name, $county_name ),
            rss_text  => sprintf( _('RSS feed for %s ward, %s'), $c_ward_name, $county_name ),
            uri       => $c->uri_for( '/rss/area/' . $county->{short_name} . '/' . $c_ward->{short_name} )
        };

        push @reported_to_options, {
            type      => 'council',
            id        => sprintf( 'council:%s:%s', $body_dis->id, $district->{id_name} ),
            text      => sprintf( _('Reports sent to %s'), $district->{name} ),
            rss_text  => sprintf( _('RSS feed of %s'), $district->{name}),
            uri       => $c->uri_for( '/rss/reports/' . $district->{short_name} ),
        }, {
            type     => 'ward',
            id       => sprintf( 'ward:%s:%s:%s:%s', $body_dis->id, $d_ward->{id}, $district->{id_name}, $d_ward->{id_name} ),
            rss_text => sprintf( _('RSS feed of %s, within %s ward'), $district->{name}, $d_ward->{name}),
            text     => sprintf( _('Reports sent to %s, within %s ward'), $district->{name}, $d_ward->{name}),
            uri      => $c->uri_for( '/rss/reports/' . $district->{short_name} . '/' . $d_ward->{short_name} ),
        }
            if $body_dis;
        push @reported_to_options, {
            type      => 'council',
            id        => sprintf( 'council:%s:%s', $body_cty->id, $county->{id_name} ),
            text      => sprintf( _('Reports sent to %s'), $county->{name} ),
            rss_text  => sprintf( _('RSS feed of %s'), $county->{name}),
            uri       => $c->uri_for( '/rss/reports/' . $county->{short_name} ),
        }, {
            type     => 'ward',
            id       => sprintf( 'ward:%s:%s:%s:%s', $body_cty->id, $c_ward->{id}, $county->{id_name}, $c_ward->{id_name} ),
            rss_text => sprintf( _('RSS feed of %s, within %s ward'), $county->{name}, $c_ward->{name}),
            text     => sprintf( _('Reports sent to %s, within %s ward'), $county->{name}, $c_ward->{name}),
            uri      => $c->uri_for( '/rss/reports/' . $county->{short_name} . '/' . $c_ward->{short_name} ),
        }
            if $body_cty;

    } else {
        throw Error::Simple('An area with three tiers of council? Impossible! '. join('|',keys %$all_areas));
    }

    return ( \@options, @reported_to_options ? \@reported_to_options : undef );
}

sub report_check_for_errors {
    my $self = shift;
    my $c = shift;

    my %errors = $self->next::method($c);

    my $report = $c->stash->{report};

    if (!$errors{name} && (length($report->name) < 5
        || $report->name !~ m/\s/
        || $report->name =~ m/\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i))
    {
        $errors{name} = _(
'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below'
        );
    }

    my $cobrand = $self->get_body_handler_for_problem($report);
    if ( $cobrand->can('report_validation') ) {
        $cobrand->report_validation( $report, \%errors );
    }

    return %errors;
}

=head2 get_body_handler_for_problem

Returns a cobrand for the body that a problem was logged against.

    my $handler = $cobrand->get_body_handler_for_problem($row);
    my $handler = $cobrand_class->get_body_handler_for_problem($row);

If the UK council in bodies_str has a FMS.com cobrand then an instance of that
cobrand class is returned, otherwise the default FixMyStreet cobrand is used.

=cut

sub get_body_handler_for_problem {
    my ($self, $row) = @_;

    if ($row->to_body_named('TfL')) {
        return FixMyStreet::Cobrand::TfL->new;
    }
    # Do not do anything for Highways England here, as we don't want it to
    # treat this as a cobrand for e.g. submit report emails made on .com

    my @bodies = values %{$row->bodies};
    my %areas = map { %{$_->areas} } grep { $_->name !~ /TfL|Highways England/ } @bodies;

    my $cobrand = FixMyStreet::Cobrand->body_handler(\%areas);
    return $cobrand if $cobrand;
    return ref $self ? $self : $self->new;
}

=head2 link_to_council_cobrand

If a problem was sent to a UK council who has a FMS cobrand and the report is
currently being viewed on a different cobrand, then link the council's name to
that problem on the council's cobrand.

=cut

sub link_to_council_cobrand {
    my ( $self, $problem ) = @_;
    # If the report was sent to a cobrand that we're not currently on,
    # include a link to view it on the responsible cobrand.
    # This only occurs if the report was sent to a single body and we're not already
    # using the body name as a link to all problem reports.
    my $handler = $self->get_body_handler_for_problem($problem);
    $self->{c}->log->debug( sprintf "bodies: %s areas: %s self: %s handler: %s", $problem->bodies_str, $problem->areas, $self->moniker, $handler->moniker );
    my $bodies_str_ids = $problem->bodies_str_ids;
    if ( !FixMyStreet->config('AREA_LINKS_FROM_PROBLEMS') &&
         scalar(@$bodies_str_ids) == 1 && $handler->is_council &&
         $handler->moniker ne $self->{c}->cobrand->moniker
       ) {
        my $url = sprintf("%s%s", $handler->base_url, $problem->url);
        return sprintf("<a href='%s'>%s</a>", $url, $problem->body( $self->{c} ));
    } else {
        return $problem->body( $self->{c} );
    }
}

sub lookup_by_ref_regex {
    return qr/^\s*(\d+)\s*$/;
}

sub category_extra_hidden {
    my ($self, $meta) = @_;
    return 1 if $meta->{code} eq 'usrn' || $meta->{code} eq 'asset_id';
    return $self->SUPER::category_extra_hidden($meta);
}

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    if ($report->to_body_named('TfL')) {
        my $tfl = FixMyStreet::Cobrand->get_class_for_moniker('tfl')->new();
        $tfl->report_new_munge_before_insert($report);
    }
}

1;
