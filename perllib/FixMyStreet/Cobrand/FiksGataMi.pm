package FixMyStreet::Cobrand::FiksGataMi;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;

sub set_lang_and_domain {
    my ( $self, $lang, $unicode, $dir ) = @_;
    mySociety::Locale::negotiate_language(
        'en-gb,English,en_GB|nb,Norwegian,nb_NO', 'nb' );
    mySociety::Locale::gettext_domain( 'FixMyStreet', $unicode, $dir );
    mySociety::Locale::change();
}

sub enter_postcode_text {
    my ( $self, $q ) = @_;
    return _('Enter a nearby postcode, or street name and area:');
}

# Is also adding language parameter
sub disambiguate_location {
    my ( $self, $s, $q ) = @_;
    $s = "hl=no&gl=no&$s";
    return $s;
}

sub area_types {
    return ( 'NKO', 'NFY' );
}

sub area_min_generation {
    return '';
}

# If lat/lon are present in the URL, OpenLayers will use that to centre the map.
# Need to specify a zoom to stop it defaulting to null/0.
sub uri {
    my ( $self, $uri ) = @_;

    $uri->query_param( zoom => 2 )
      if $uri->query_param('lat') && !$uri->query_param('zoom');

    return $uri;
}

sub geocoded_string_check {
    my ( $self, $s ) = @_;
    return 1 if $s =~ /, Norge/;
    return 0;
}

sub remove_redundant_councils {
  my $self = shift;
  my $all_councils = shift;

  # Oslo is both a kommune and a fylke, we only want to show it once
  delete $all_councils->{301}     #
    if $all_councils->{3};
}

1;
