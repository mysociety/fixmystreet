package FixMyStreet::Cobrand::FixaMinGata;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;
use utf8;

use Carp;
use mySociety::MaPit;
use DateTime;

sub country {
    return 'SE';
}

sub languages { [ 'sv,Swedish,sv_SE' ] }
sub language_override { 'sv' }

sub enter_postcode_text {
    my ( $self ) = @_;
    return _('Enter a nearby postcode, or street name and area');
}

# Is also adding language parameter
sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $out = {
        %{ $self->SUPER::disambiguate_location() },
        lang => 'sv',
        country => 'se',
    };

    $string = lc($string);

    if ($string eq 'lysekil') {
        # Lysekil
        $out->{bounds} = [ '58.4772', '11.3983', '58.1989', '11.5755' ];
    } elsif ($string eq 'tjörn') {
        # Tjörn
        $out->{bounds} = [ '58.0746', '11.4429', '57.9280', '11.7815' ];
    } elsif ($string eq 'varmdö') {
        # Varmdö
        $out->{bounds} = [ '59.4437', '18.3513', '59.1907', '18.7688' ];
    } elsif ($string eq 'öckerö') {
        # Öckerö
        $out->{bounds} = [ '57.7985', '11.5792', '57.6265', '11.7108' ];
    }

    return $out;
}

sub geocoder_munge_results {
    my ($self, $result) = @_;

    if ($result->{osm_id} == 1076755) { # Hammarö, Hammarö, Värmlands län, Svealand, Sweden
        $result->{lat} = 59.3090;
        $result->{lon} = 13.5297;
    }

    if ($result->{osm_id} == 398625) { # Haninge, Landskapet Södermanland, Stockholms län, Svealand, Sweden
        $result->{lat} = 59.1069;
        $result->{lon} = 18.2085;
    }

    if ($result->{osm_id} == 5831132) { # Nordmaling District, Nordmaling, Ångermanland, Västerbottens län, Norrland, 91433, Sweden
        $result->{lat} = 63.5690;
        $result->{lon} = 19.5028;
    }

    if ($result->{osm_id} == 935430) { # Sotenäs, Västra Götalands län, Götaland, Sweden
        $result->{lat} = 58.4219;
        $result->{lon} = 11.3345;
    }

    if ($result->{osm_id} == 935640) { # Tanum, Västra Götalands län, Götaland, Sweden
        $result->{lat} = 58.7226;
        $result->{lon} = 11.3242;
    }

    if ($result->{osm_id} == 289344) { # Älvkarleby, Landskapet Uppland, Uppsala län, Svealand, Sweden
        $result->{lat} = 60.5849;
        $result->{lon} = 17.4545;
    }
}

sub area_types {
    my $self = shift;
    return $self->next::method() if FixMyStreet->staging_flag('skip_checks');
    [ 'KOM' ];
}

sub geocode_postcode {
    my ( $self, $s ) = @_;
    # Most people write Swedish postcodes like this:
    # XXX XX, so let's remove the space
    $s =~ s/\ //g;
    if ($s =~ /^\d{5}$/) {
        my $location = mySociety::MaPit::call('postcode', $s);
        if ($location->{error}) {
            return {
                error => $location->{code} =~ /^4/
                    ? _('That postcode was not recognised, sorry.')
                    : $location->{error}
            };
        }
        return {
            latitude  => $location->{wgs84_lat},
            longitude => $location->{wgs84_lon},
        };
    }
    return {};
}

# Vad gör den här funktionen? Är "Sverige" rätt här?
sub geocoded_string_check {
    my ( $self, $s ) = @_;
    return 1 if $s =~ /, Sverige/;
    return 0;
}

sub find_closest {
    my ( $self, $problem ) = @_;
    $problem = $problem->{problem} if ref $problem eq 'HASH';
    return FixMyStreet::Geocode::OSM::closest_road_text( $self, $problem->latitude, $problem->longitude );
}

# Used by send-reports, calling find_closest, calling OSM geocoding
sub guess_road_operator {
    my ( $self, $inforef ) = @_;

    my $highway = $inforef->{highway} || "unknown";
    my $refs    = $inforef->{ref}     || "unknown";
    return "Trafikverket"
        if $highway eq "trunk" || $highway eq "primary";

    for my $ref (split(/;/, $refs)) {
        return "Trafikverket"
            if $ref =~ m/E ?\d+/ || $ref =~ m/Fv\d+/i;
    }
    return '';
}

sub remove_redundant_councils {
    my $self = shift;
    my $all_councils = shift;

    # Oslo is both a kommune and a fylke, we only want to show it once
    # Jag tror inte detta är applicerbart på Sverige ;-) //Rikard
    #delete $all_councils->{301}     #
    #    if $all_councils->{3};
}

sub filter_all_council_ids_list {
    my $self = shift;
    my @all_councils_ids = @_;

    # as above we only want to show Oslo once
    # Rikard kommenterar ut detta.
    # return grep { $_ != 301 } @all_councils_ids;
    # Rikard:
    return  @all_councils_ids; # Är detta rätt? //Rikard
}

# The pin is green is it's fixed or closed, yellow if it's in progress (not in a
# confirmed state), and red otherwise.
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->is_in_progress;
    return 'red';
}

sub state_groups_inspect {
    [
        [ _('Open'), [ 'confirmed', 'action scheduled', 'in progress', 'investigating' ] ],
        [ _('Fixed'), [ 'fixed - council' ] ],
        [ _('Closed'), [ 'duplicate', 'not responsible', 'unable to fix' ] ],
    ]
}

sub always_view_body_contribute_details {
    return 1;
}

# Average responsiveness will only be calculated if a body
# has at least this many fixed reports.
# (Used in the Top 5 list in /reports)
sub body_responsiveness_threshold {
    return 5;
}

sub suggest_duplicates { 1 }

sub default_show_name { 1 }

1;
