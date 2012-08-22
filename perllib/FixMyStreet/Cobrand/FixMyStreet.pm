package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

sub area_types          { return qw(DIS LBO MTD UTA CTY COI); }
sub area_min_generation { 10 }

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

sub enter_postcode_text {
    my ( $self ) = @_;
    return _("Enter a nearby GB postcode, or street name and area");
}

sub admin_base_url {
    return 'https://secure.mysociety.org/admin/bci/';
}

1;

