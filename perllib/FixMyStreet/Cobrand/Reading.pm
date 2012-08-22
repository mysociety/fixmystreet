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
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Reading',
        centre => '51.452983,-0.983827',
        span   => '0.083355,0.1245',
        bounds => [ 51.409779, -1.052994, 51.493134, -0.928494 ],
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
