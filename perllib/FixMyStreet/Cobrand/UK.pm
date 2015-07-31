package FixMyStreet::Cobrand::UK;
use base 'FixMyStreet::Cobrand::Default';

use mySociety::MaPit;
use mySociety::VotingArea;

sub country             { return 'GB'; }
sub area_types          { [ 'DIS', 'LBO', 'MTD', 'UTA', 'CTY', 'COI', 'LGD' ] }
sub area_types_children { $mySociety::VotingArea::council_child_types }

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

sub process_extras {
    my $self    = shift;
    my $ctx     = shift;
    my $body_id = shift;
    my $extra   = shift;
    my $fields  = shift || [];

    # XXX Hardcoded body ID matching mapit area ID
    if ( $body_id eq '2482' ) {
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
    }
    return {};
}

sub remove_redundant_areas {
  my $self = shift;
  my $all_areas = shift;

  # Norwich is responsible for everything in its areas, not Norfolk
  delete $all_areas->{2233}    #
    if $all_areas->{2391};
}

sub short_name {
    my $self = shift;
    my ($area) = @_;

    my $name = $area->{name} || $area->name;

    # Special case Durham as it's the only place with two councils of the same name
    return 'Durham+County' if $name eq 'Durham County Council';
    return 'Durham+City' if $name eq 'Durham City Council';

    $name =~ s/ (Borough|City|District|County) Council$//;
    $name =~ s/ Council$//;
    $name =~ s/ & / and /;
    $name =~ s{/}{_}g;
    $name = URI::Escape::uri_escape_utf8($name);
    $name =~ s/%20/+/g;
    return $name;
}

sub find_closest {
    my ( $self, $latitude, $longitude, $problem ) = @_;

    my $str = $self->SUPER::find_closest( $latitude, $longitude, $problem );

    my $url = "http://mapit.mysociety.org/nearest/4326/$longitude,$latitude";
    my $j = LWP::Simple::get($url);
    if ($j) {
        $j = JSON->new->utf8->allow_nonref->decode($j);
        if ($j->{postcode}) {
            $str .= sprintf(_("Nearest postcode to the pin placed on the map (automatically generated): %s (%sm away)"),
                $j->{postcode}{postcode}, $j->{postcode}{distance}) . "\n\n";
        }
    }

    return $str;
}

sub reports_body_check {
    my ( $self, $c, $code ) = @_;

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
        foreach (values %$all_areas) {
            if ($councils{$_->{type}}) {
                $council = $_;
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

        push @options, {
            type  => 'area',
            id    => sprintf( 'area:%s:%s', $district->{id}, $district->{id_name} ),
            text  => $district_name,
            rss_text => sprintf( _('RSS feed for %s'), $district_name ),
            uri => $c->uri_for( '/rss/area/' . $district->{short_name}  )
        }, {
            type      => 'area',
            id        => sprintf( 'area:%s:%s:%s:%s', $district->{id}, $d_ward->{id}, $district->{id_name}, $d_ward->{id_name} ),
            text      => sprintf( _('%s ward, %s'), $d_ward_name, $district_name ),
            rss_text  => sprintf( _('RSS feed for %s ward, %s'), $d_ward_name, $district_name ),
            uri       => $c->uri_for( '/rss/area/' . $district->{short_name} . '/' . $d_ward->{short_name} )
        }, {
            type  => 'area',
            id    => sprintf( 'area:%s:%s', $county->{id}, $county->{id_name} ),
            text  => $county_name,
            rss_text => sprintf( _('RSS feed for %s'), $county_name ),
            uri => $c->uri_for( '/rss/area/' . $county->{short_name}  )
        }, {
            type      => 'area',
            id        => sprintf( 'area:%s:%s:%s:%s', $county->{id}, $c_ward->{id}, $county->{id_name}, $c_ward->{id_name} ),
            text      => sprintf( _('%s ward, %s'), $c_ward_name, $county_name ),
            rss_text  => sprintf( _('RSS feed for %s ward, %s'), $c_ward_name, $county_name ),
            uri       => $c->uri_for( '/rss/area/' . $county->{short_name} . '/' . $c_ward->{short_name} )
        };

        push @reported_to_options, {
            type      => 'council',
            id        => sprintf( 'council:%s:%s', $district->{id}, $district->{id_name} ),
            text      => $district->{name},
            rss_text  => sprintf( _('RSS feed of %s'), $district->{name}),
            uri       => $c->uri_for( '/rss/reports/' . $district->{short_name} ),
        }, {
            type     => 'ward',
            id       => sprintf( 'ward:%s:%s:%s:%s', $district->{id}, $d_ward->{id}, $district->{id_name}, $d_ward->{id_name} ),
            rss_text => sprintf( _('RSS feed of %s, within %s ward'), $district->{name}, $d_ward->{name}),
            text     => sprintf( _('%s, within %s ward'), $district->{name}, $d_ward->{name}),
            uri      => $c->uri_for( '/rss/reports/' . $district->{short_name} . '/' . $d_ward->{short_name} ),
        }, {
            type      => 'council',
            id        => sprintf( 'council:%s:%s', $county->{id}, $county->{id_name} ),
            text      => $county->{name},
            rss_text  => sprintf( _('RSS feed of %s'), $county->{name}),
            uri       => $c->uri_for( '/rss/reports/' . $county->{short_name} ),
        }, {
            type     => 'ward',
            id       => sprintf( 'ward:%s:%s:%s:%s', $county->{id}, $c_ward->{id}, $county->{id_name}, $c_ward->{id_name} ),
            rss_text => sprintf( _('RSS feed of %s, within %s ward'), $county->{name}, $c_ward->{name}),
            text     => sprintf( _('%s, within %s ward'), $county->{name}, $c_ward->{name}),
            uri      => $c->uri_for( '/rss/reports/' . $county->{short_name} . '/' . $c_ward->{short_name} ),
        };

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

    # XXX Hardcoded body ID matching mapit area ID
    if ( $report->bodies_str && $report->detail ) {
        # Custom character limit:
        # Bromley Council
        if ( $report->bodies_str eq '2482' && length($report->detail) > 1750 ) {
            $errors{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1750 );
        }
        # Oxfordshire
        if ( $report->bodies_str eq '2237' && length($report->detail) > 1700 ) {
            $errors{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1700 );
        }
    }

    return %errors;
}

1;

