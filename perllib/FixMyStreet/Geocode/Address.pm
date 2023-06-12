package FixMyStreet::Geocode::Address;

use strict;
use warnings;
use JSON::MaybeXS;
use FixMyStreet::Geocode::Address::Bing;
use FixMyStreet::Geocode::Address::OSM;
use FixMyStreet::Geocode::Address::OSPlaces;

use overload '""' => \&as_string, fallback => 1;

sub new {
    my ($class, $data) = @_;

    my $self;
    if (ref $data) {
        $self = { %$data };
    } elsif ($data) {
        $self = JSON::MaybeXS->new->allow_nonref->decode($data);
    } else {
        $self = {};
    }

    my $type;
    if ($self->{resourceSets}) {
        $type = 'Bing';
    } elsif ($self->{LPI}) {
        $type = 'OSPlaces';
    } else {
        $type = 'OSM';
    }

    bless $self, "FixMyStreet::Geocode::Address::$type";
}

sub as_string {
    my $self = shift;

    my $summary = $self->summary;
    return '' unless $summary;

    my $data = sprintf($self->label, $self->brand, $summary) . "\n\n";

    if ($self->{postcode}) {
        $data .= sprintf(_("Nearest postcode to the pin placed on the map (automatically generated): %s (%sm away)"),
            $self->{postcode}{postcode}, $self->{postcode}{distance}) . "\n\n";
    }

    return $data;
}

1;
