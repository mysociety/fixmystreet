package FixMyStreet::Cobrand::UKCouncils;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;
use URI::Escape;

sub is_council {
    1;
}

sub site_restriction {
    my $self = shift;
    return ( "and council='" . $self->council_id . "'", $self->council_url, { council => sprintf('%d', $self->council_id) } );
}

sub restriction {
    return { cobrand => shift->moniker };
}

sub problems_clause {
    my $self = shift;
    return { council => sprintf('%d', $self->council_id) };
}

sub problems {
    my $self = shift;
    return $self->{c}->model('DB::Problem')->search( $self->problems_clause );
}

sub base_url {
    my $self = shift;
    my $base_url = mySociety::Config::get('BASE_URL');
    my $u = $self->council_url;
    if ( $base_url !~ /$u/ ) {
        $base_url =~ s{http://(?!www\.)}{http://$u.}g;
        $base_url =~ s{http://www\.}{http://$u.}g;
    }
    return $base_url;
}

sub site_title {
    my ($self) = @_;
    return $self->council_name . ' FixMyStreet';
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a ' . $self->council_area . ' postcode, or street name and area';
}

sub council_check {
    my ( $self, $params, $context ) = @_;

    my $councils = $params->{all_councils};
    my $council_match = defined $councils->{$self->council_id};
    if ($council_match) {
        return 1;
    }
    my $url = 'http://www.fixmystreet.com/';
    if ($context eq 'alert') {
        $url .= 'alert';
    } else {
        $url .= 'around';
    }
    $url .= '?pc=' . URI::Escape::uri_escape( $self->{c}->req->param('pc') )
      if $self->{c}->req->param('pc');
    $url .= '?latitude=' . URI::Escape::uri_escape( $self->{c}->req->param('latitude') )
         .  '&amp;longitude=' . URI::Escape::uri_escape( $self->{c}->req->param('longitude') )
      if $self->{c}->req->param('latitude');
    my $error_msg = "That location is not covered by " . $self->council_name . ".
Please visit <a href=\"$url\">the main FixMyStreet site</a>.";
    return ( 0, $error_msg );
}

# All reports page only has the one council.
sub all_councils_report {
    return 0;
}

sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    $num = 2 if $num == 3;
    return $self->problems->recent_photos( $num, $lat, $lon, $dist );
}

sub get_council_sender {
    my ( $self, $area_id, $area_info ) = @_;

    my $send_method;

    my $council_config = FixMyStreet::App->model("DB::Open311conf")->search( { area_id => $area_id } )->first;
    $send_method = $council_config->send_method if $council_config;

    return $send_method if $send_method;

    return 'London' if $area_info->{type} eq 'LBO';

    return 'Email';
}

1;
