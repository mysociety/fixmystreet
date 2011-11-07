package FixMyStreet::Cobrand::Reading;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;
use URI::Escape;
use mySociety::VotingArea;

sub site_restriction {
    return ( "and council='2596'", 'reading', { council => '2596' } );
}

sub problems_clause {
    return { council => '2596' };
}

sub problems {
    my $self = shift;
    return $self->{c}->model('DB::Problem')->search( $self->problems_clause );
}

sub base_url {
   my $base_url = mySociety::Config::get('BASE_URL');
   if ($base_url !~ /reading/) {
       $base_url =~ s{http://(?!www\.)}{http://reading.}g;
       $base_url =~ s{http://www\.}{http://reading.}g;
   }
   return $base_url;
}

sub site_title {
    my ( $self ) = @_;
    return 'Reading City Council FixMyStreet';
}

sub enter_postcode_text {
    my ( $self ) = @_;
    return 'Enter a Reading postcode, or street name and area';
}

sub council_check {
    my ( $self, $params, $context ) = @_;

    my $councils = $params->{all_councils};
    my $council_match = defined $councils->{2596};
    if ($council_match) {
        return 1;
    }
    my $url = 'http://www.fixmystreet.com/';
    $url .= 'alert' if $context eq 'alert';
    $url .= '?pc=' . URI::Escape::uri_escape_utf8($self->{c}->req->param('pc'))
        if $self->{c}->req->param('pc');
    my $error_msg = "That location is not covered by Reading.
Please visit <a href=\"$url\">the main FixMyStreet site</a>.";
    return ( 0, $error_msg );
}

# All reports page only has the one council.
sub all_councils_report {
    return 0;
}

sub disambiguate_location {
    return {
        town   => 'Reading',
        centre => '51.452983169803964,-0.98382678731985973',
        span   => '0.0833543573028663,0.124500468843446',
        bounds => [ '51.409779668156361,-1.0529948144525243', '51.493134025459227,-0.92849434560907829' ],
    };
}

sub recent_photos {
    my ($self, $num, $lat, $lon, $dist) = @_;
    $num = 2 if $num == 3;
    return $self->problems->recent_photos( $num, $lat, $lon, $dist );
}

sub get_report_stats {
    my $self = shift;

    my ( $cobrand, $main_site ) = ( 0, 0 );

    $self->{c}->log->debug( 'X' x 60 );
    my $stats = $self->{c}->model('DB::Problem')->search(
        { confirmed => { '>=', '2011-11-01' } },
        {
            select   => [ { count => 'id', -as => 'cobrand_count' }, 'cobrand' ],
            group_by => [qw/cobrand/]
        }
    );

    while ( my $stat = $stats->next ) {
        if ( $stat->cobrand eq $self->moniker ) {
            $cobrand += $stat->get_column( 'cobrand_count' );
        } else {
            $main_site += $stat->get_column( 'cobrand_count' );
        }
    }

    return {
        cobrand     => $cobrand,
        main_site   => $main_site,
    };
}

1;
