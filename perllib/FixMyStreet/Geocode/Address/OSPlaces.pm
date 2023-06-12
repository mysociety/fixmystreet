package FixMyStreet::Geocode::Address::OSPlaces;

use parent 'FixMyStreet::Geocode::Address';

sub brand { "OS Places API" }

sub label { _("Nearest address to the pin placed on the map (from %s): %s") }

sub recase {
    my $s = shift;
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
        number => $_[0]->line1,
        street => recase($address->{STREET_DESCRIPTION} || ''),
        postcode => recase($address->{POSTCODE_LOCATOR} || ''),
    };
}

sub for_around {
    my $self = shift;
    return {
        road => recase($self->{LPI}{STREET_DESCRIPTION}),
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

sub line1 {
    my $self = shift;
    my $address = $self->{LPI};
    my $str = '';
    $str .= recase($address->{ORGANISATION_NAME}) . ', ' if $address->{ORGANISATION_NAME};
    $str .= $address->{SAO_START_NUMBER} if $address->{SAO_START_NUMBER};
    $str .= $address->{SAO_START_SUFFIX} if $address->{SAO_START_SUFFIX};
    $str .= '-' . $address->{SAO_END_NUMBER} if $address->{SAO_END_NUMBER};
    $str .= $address->{SAO_END_SUFFIX} if $address->{SAO_END_SUFFIX};
    $str .= ' ' . recase($address->{SAO_TEXT}) . ',' if $address->{SAO_TEXT};
    $str .= ' ';
    $str .= $address->{PAO_START_NUMBER} if $address->{PAO_START_NUMBER};
    $str .= $address->{PAO_START_SUFFIX} if $address->{PAO_START_SUFFIX};
    $str .= '-' . $address->{PAO_END_NUMBER} if $address->{PAO_END_NUMBER};
    $str .= $address->{PAO_END_SUFFIX} if $address->{PAO_END_SUFFIX};
    $str .= ' ' . recase($address->{PAO_TEXT}) . ',' if $address->{PAO_TEXT};
    $str .= ' ';
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

1;
