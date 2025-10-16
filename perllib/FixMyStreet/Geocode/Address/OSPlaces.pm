package FixMyStreet::Geocode::Address::OSPlaces;

use strict;
use warnings;
use parent 'FixMyStreet::Geocode::Address';

sub brand { "OS Places API" }

sub label { _("Nearest address to the pin placed on the map (from %s): %s") }

sub recase {
    my $s = shift || '';
    $s =~ s/([\w']+)/\u\L$1/g;
    return $s;
}

sub summary {
    my $s = $_[0]->{LPI}{ADDRESS};
    my @s = split /, /, $s;
    my $pc = pop @s;
    $s = recase(join(', ', @s));
    return "$s, $pc";
}

sub parts {
    my $address = $_[0]->{LPI};
    return {
        number => join(', ', $_[0]->addressable_objects(1)),
        street => $_[0]->street_description,
        postcode => $address->{POSTCODE_LOCATOR} || '',
        uprn => $address->{UPRN},
    };
}

sub multiline {
    my ($self, $lines) = @_;
    my $address = $self->{LPI};
    my $org = recase($address->{ORGANISATION});
    my $locality = recase($address->{LOCALITY});
    my @parts = $self->addressable_objects;
    push @parts, $locality if $locality;

    my @address;
    if ($lines == 5) { # Particular format
        if (@parts == 4) {
            push @address, "$parts[0], $parts[1]", $parts[2], $parts[3];
        } elsif (@parts == 3) {
            push @address, @parts;
        } else {
            push @address, $org if $org;
            push @address, @parts;
        }
        push @address, "" while @address < 3;
        push @address, recase($address->{TOWN_NAME});
        push @address, $address->{POSTCODE_LOCATOR} || '';
    } else {
        push @address, $org if $org;
        push @address, @parts;
        push @address, recase($address->{TOWN_NAME}) if $address->{TOWN_NAME};
        push @address, $address->{POSTCODE_LOCATOR} if $address->{POSTCODE_LOCATOR};
    }

    return join("\n", @address);
}

sub for_around {
    my $self = shift;
    return {
        road => $self->street_description,
        full_address => $self->summary,
    };
}

sub for_alert {
    my $self = shift;

    my $address = $self->{LPI};
    my @address;
    push @address, $address->{STREET_DESCRIPTION};
    push @address, $address->{LOCALITY_NAME} if $address->{LOCALITY_NAME};
    push @address, $address->{TOWN_NAME} if $address->{TOWN_NAME};

    my $str = '';
    $str .= sprintf($self->label, $self->brand, recase(join(', ', @address)) ) if @address;
    return $str;
}

sub addressable_objects {
    my ($self, $no_street) = @_;
    my $address = $self->{LPI};
    my @saon = addressable_object($address, 'SAO');
    my @paon = addressable_object($address, 'PAO');
    my $saot = recase($address->{SAO_TEXT});
    my $paot = recase($address->{PAO_TEXT});

    my $street = $no_street ? "" : $self->street_description;
    $street = join(' ', @paon, $street);
    $street = join(', ', @saon, $street) if !$paot;

    my @parts;
    push @parts, $saot if $saot;
    push @parts, join(' ', @saon, $paot) if $paot;
    push @parts, $street if $street;
    return @parts;
}

# Returns a list - either the number/range, or empty.
# This is so it is easy to use in a join if missing
sub addressable_object {
    my ($address, $type) = @_;
    my $str = '';
    $str .= $address->{$type . '_START_NUMBER'} if $address->{$type . '_START_NUMBER'};
    $str .= $address->{$type . '_START_SUFFIX'} if $address->{$type . '_START_SUFFIX'};
    $str .= '-' . $address->{$type . '_END_NUMBER'} if $address->{$type . '_END_NUMBER'};
    $str .= $address->{$type . '_END_SUFFIX'} if $address->{$type . '_END_SUFFIX'};
    return $str ? ($str) : ();
}

sub street_description { recase($_[0]->{LPI}{STREET_DESCRIPTION}) }

1;
