package FixMyStreet::Cobrand::Barnet;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;
use URI::Escape;
use mySociety::VotingArea;

sub site_restriction {
    return ( "and council='2489'", 'barnet', { council => '2489' } );
}

sub problems_clause {
    return { council => '2489' };
}

sub problems {
    my $self = shift;
    return $self->{c}->model('DB::Problem')->search( $self->problems_clause );
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
    return 'Enter a Barnet postcode, or street name and area';
}

sub council_check {
    my ( $self, $params, $context ) = @_;

    my $councils = $params->{all_councils};
    my $council_match = defined $councils->{2489};
    if ($council_match) {
        return 1;
    }
    my $url = 'http://www.fixmystreet.com/';
    $url .= 'alert' if $context eq 'alert';
    $url .= '?pc=' . URI::Escape::uri_escape( $self->{c}->req->param('pc') )
      if $self->{c}->req->param('pc');
    my $error_msg = "That location is not covered by Barnet.
Please visit <a href=\"$url\">the main FixMyStreet site</a>.";
    return ( 0, $error_msg );
}

# All reports page only has the one council.
sub all_councils_report {
    return 0;
}

sub disambiguate_location {
    return {
        centre => '51.612832,-0.218169',
        span   => '0.0563,0.09',
        bounds => [ '51.584682,-0.263169', '51.640982,-0.173169' ],
    };
}

sub recent_photos {
    my ( $self, $num, $lat, $lon, $dist ) = @_;
    $num = 2 if $num == 3;
    return $self->problems->recent_photos( $num, $lat, $lon, $dist );
}

sub tilma_mid_point {
    return 189;
}

1;

