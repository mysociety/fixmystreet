package FixMyStreet::Cobrand::FiksGataMi;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;
use mySociety::MaPit;

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

sub short_name {
  my $self = shift;
  my ($area, $info) = @_;

  if ($area->{name} =~ /^(Os|Nes|V\xe5ler|Sande|B\xf8|Her\xf8y)$/) {
      my $parent = $info->{$area->{parent_area}}->{name};
      return URI::Escape::uri_escape_utf8("$area->{name}, $parent");
  }

  my $name = $area->{name};
  $name =~ s/ & / and /;
  $name = URI::Escape::uri_escape_utf8($name);
  $name =~ s/%20/+/g;
  return $name;

}

sub reports_council_check {
    my ( $self, $c, $council ) = @_;

    if ($council eq 'Oslo') {

        # There are two Oslos (kommune and fylke), we only want one of them.
        $c->stash->{council} = mySociety::MaPit::call('area', 3);
        return 1;

    } elsif ($council =~ /,/) {

        # Some kommunes have the same name, use the fylke name to work out which.
        my ($kommune, $fylke) = split /\s*,\s*/, $council;
        my @area_types = $c->cobrand->area_types;
        my $areas_k = mySociety::MaPit::call('areas', $kommune, type => \@area_types);
        my $areas_f = mySociety::MaPit::call('areas', $fylke, type => \@area_types);
        use Data::Dumper;
        if (keys %$areas_f == 1) {
            ($fylke) = values %$areas_f;
            foreach (values %$areas_k) {
                if ($_->{name} eq $kommune && $_->{parent_area} == $fylke->{id}) {
                    $c->stash->{council} = $_;
                    return 1;
                }
            }
        }
        # If we're here, we've been given a bad name.
        $c->detach( 'redirect_index' );

    }
}

1;
