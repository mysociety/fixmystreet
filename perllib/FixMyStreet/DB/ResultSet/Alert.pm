package FixMyStreet::DB::ResultSet::Alert;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub timeline_created {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        {
            whensubscribed => { '>=', \"current_timestamp-'7 days'::interval" },
            confirmed => 1,
            %{ $restriction },
        },
        {
            prefetch => [ qw/alert_type user/ ],
        }
    );
}

sub timeline_disabled {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        {
            whendisabled => { '>=', \"current_timestamp-'7 days'::interval" },
            %{ $restriction },
        },
    );
}

# Return summary for alerts on reports (so excluding alerts on updates)
sub summary_report_alerts {
    my ( $rs, $restriction ) = @_;
    $rs = $rs->search({ alert_type => { '!=', 'new_updates' } });
    return $rs->summary_count($restriction);
}

sub summary_count {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        $restriction,
        {
            group_by => ['confirmed'],
            select   => [ 'confirmed', { count => 'id' } ],
            as       => [qw/confirmed confirmed_count/]
        }
    );
}

1;
