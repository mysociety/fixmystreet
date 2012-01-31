package FixMyStreet::Cobrand::Reading;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use Carp;

sub council_id { return 2596; }
sub council_area { return 'Reading'; }
sub council_name { return 'Reading City Council'; }
sub council_url { return 'reading'; }

sub disambiguate_location {
    return {
        town   => 'Reading',
        centre => '51.452983169803964,-0.98382678731985973',
        span   => '0.0833543573028663,0.124500468843446',
        bounds => [ '51.409779668156361,-1.0529948144525243', '51.493134025459227,-0.92849434560907829' ],
    };
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
