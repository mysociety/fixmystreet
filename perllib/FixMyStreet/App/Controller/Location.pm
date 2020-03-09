package FixMyStreet::App::Controller::Location;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

use Encode;
use FixMyStreet::Geocode;
use Try::Tiny;
use Utils;

=head1 NAME

FixMyStreet::App::Controller::Location - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

This is purely an internal controller for keeping all the location finding things in one place

=head1 METHODS

=head2 determine_location_from_coords

Use latitude and longitude if provided in parameters.

=cut 

sub determine_location_from_coords : Private {
    my ( $self, $c ) = @_;

    my $latitude = $c->get_param('latitude') || $c->get_param('lat');
    my $longitude = $c->get_param('longitude') || $c->get_param('lon');

    if ( defined $latitude && defined $longitude ) {
        ($c->stash->{latitude}, $c->stash->{longitude}) =
            map { Utils::truncate_coordinate($_) } ($latitude, $longitude);

        # Also save the pc if there is one
        if ( my $pc = $c->get_param('pc') ) {
            $c->stash->{pc} = $pc;
        }

        return $c->forward( 'check_location' );
    }

    return;
}

=head2 determine_location_from_pc

User has searched for a location - try to find it for them.

Return false if nothing provided.

If one match is found returns true and lat/lng is set.

If several possible matches are found puts an array onto stash so that user can be prompted to pick one and returns false.

If no matches are found returns false.

=cut 

sub determine_location_from_pc : Private {
    my ( $self, $c, $pc ) = @_;

    # check for something to search
    $pc ||= $c->get_param('pc') || return;
    $c->stash->{pc} = $pc;    # for template

    if ( $pc =~ /^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/ ) {
        ($c->stash->{latitude}, $c->stash->{longitude}) =
            map { Utils::truncate_coordinate($_) } ($1, $2);
        return $c->forward( 'check_location' );
    }
    if ( $c->cobrand->country eq 'GB' && $pc =~ /^([A-Z])([A-Z])([\d\s]{4,})$/i) {
        if (my $convert = gridref_to_latlon( $1, $2, $3 )) {
            ($c->stash->{latitude}, $c->stash->{longitude}) =
                map { Utils::truncate_coordinate($_) }
                ($convert->{latitude}, $convert->{longitude});
            return $c->forward( 'check_location' );
        }
    }

    my ( $latitude, $longitude, $error ) =
        FixMyStreet::Geocode::lookup( $pc, $c );

    # If we got a lat/lng set to stash and return true
    if ( defined $latitude && defined $longitude ) {
        $c->stash->{latitude}  = $latitude;
        $c->stash->{longitude} = $longitude;
        return $c->forward( 'check_location' );
    }

    # $error doubles up to return multiple choices by being an array
    if ( ref($error) eq 'ARRAY' ) {
        foreach (@$error) {
            my $a = $_->{address};
            $a =~ s/, United Kingdom//;
            $a =~ s/, UK//;
            $_->{address} = $a;
        }
        $c->stash->{possible_location_matches} = $error;
        return;
    }

    # pass errors back to the template
    $c->stash->{location_error_pc_lookup} = 1;
    $c->stash->{location_error} = $error;

    # Log failure in a log db
    try {
        my $dbfile = FixMyStreet->path_to('../data/analytics.sqlite');
        my $db = DBI->connect("dbi:SQLite:dbname=$dbfile", undef, undef, { PrintError => 0 }) or die "$DBI::errstr\n";
        my $sth = $db->prepare("INSERT INTO location_searches_with_no_results
            (datetime, cobrand, geocoder, url, user_input)
            VALUES (?, ?, ?, ?, ?)") or die $db->errstr . "\n";
        my $rv = $sth->execute(
            POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time())),
            $c->cobrand->moniker,
            $c->cobrand->get_geocoder(),
            $c->stash->{geocoder_url},
            $pc,
        );
    } catch {
        $c->log->debug("Unable to log to analytics.sqlite: $_");
    };

    return;
}

sub determine_location_from_bbox : Private {
    my ( $self, $c ) = @_;

    my $bbox = $c->get_param('bbox');
    return unless $bbox;

    my ($min_lon, $min_lat, $max_lon, $max_lat) = split /,/, $bbox;
    my $longitude = ($max_lon + $min_lon ) / 2;
    my $latitude = ($max_lat + $min_lat ) / 2;
    $c->stash->{bbox} = $bbox;
    $c->stash->{latitude} = $latitude;
    $c->stash->{longitude} = $longitude;
    return $c->forward('check_location');
}

=head2 check_location

Just make sure that for UK installs, our co-ordinates are indeed in the UK.

=cut

sub check_location : Private {
    my ( $self, $c ) = @_;

    if ( $c->stash->{latitude} && $c->cobrand->country eq 'GB' ) {
        eval { Utils::convert_latlon_to_en( $c->stash->{latitude}, $c->stash->{longitude} ); };
        if (my $error = $@) {
            mySociety::Locale::pop(); # We threw exception, so it won't have happened.
            $error = _('That location does not appear to be in the UK; please try again.')
                if $error =~ /of the area covered/;
            $c->stash->{location_error} = $error;
            return;
        }
    }

    return 1;
}

# Utility function for if someone (rarely) enters a grid reference
sub gridref_to_latlon {
    my ( $a, $b, $num ) = @_;
    $a = ord(uc $a) - 65; $a-- if $a > 7;
    $b = ord(uc $b) - 65; $b-- if $b > 7;
    my $e = (($a-2)%5)*5 + $b%5;
    my $n = 19 - int($a/5)*5 - int($b/5);

    $num =~ s/\s+//g;
    my $l = length($num);
    return if $l % 2 or $l > 10;

    $l /= 2;
    $e .= substr($num, 0, $l);
    $n .= substr($num, $l);

    if ( $l < 5 ) {
        $e .= 5;
        $n .= 5;
        $e .= 0 x (4-$l);
        $n .= 0 x (4-$l);
    }

    my ( $lat, $lon ) = Utils::convert_en_to_latlon( $e, $n );
    return {
        latitude => $lat,
        longitude => $lon,
    };
}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
