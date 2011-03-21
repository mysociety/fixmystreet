package FixMyStreet::Cobrand::Barnet;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;
use URI::Escape;
use mySociety::VotingArea;

sub site_restriction {
    return ( "and council='2489'", 'barnet' );
}

sub base_url {
    my $base_url = mySociety::Config::get('BASE_URL');
    if ( $base_url !~ /barnet/ ) {
        $base_url =~ s{http://(?!www\.)}{http://barnet.}g;
        $base_url =~ s{http://www\.}{http://barnet.}g;
    }
    return $base_url;
}

sub site_title {
    my ($self) = @_;
    return 'Barnet Council FixMyStreet';
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a Barnet postcode, or street name and area:';
}

sub council_check {
    my ( $self, $params, $context ) = @_;
    my $q = $self->request;

    my $councils;
    if ( $params->{all_councils} ) {
        $councils = $params->{all_councils};
    }
    elsif ( defined $params->{lat} ) {
        my $parent_types = $mySociety::VotingArea::council_parent_types;
        $councils = mySociety::MaPit::call(
            'point',
            "4326/$params->{lon},$params->{lat}",
            type => $parent_types
        );
    }
    my $council_match = defined $councils->{2489};
    if ($council_match) {
        return 1;
    }
    my $url = 'http://www.fixmystreet.com/';
    $url .= 'alert' if $context eq 'alert';
    $url .= '?pc=' . URI::Escape::uri_escape( $q->param('pc') )
      if $q->param('pc');
    my $error_msg = "That location is not covered by Barnet.
Please visit <a href=\"$url\">the main FixMyStreet site</a>.";
    return ( 0, $error_msg );
}

# All reports page only has the one council.
sub all_councils_report {
    return 0;
}

sub disambiguate_location {
    my ( $self, $s, $q ) = @_;
    $s = "ll=51.612832,-0.218169&spn=0.0563,0.09&$s";
    return $s;
}

sub recent_photos {
    my ( $self, $num, $lat, $lon, $dist ) = @_;
    $num = 2 if $num == 3;
    return Problems::recent_photos( $num, $lat, $lon, $dist );
}

1;

