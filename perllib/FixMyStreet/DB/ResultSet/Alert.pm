package FixMyStreet::DB::ResultSet::Alert;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub timeline_created {
    my ( $rs, $restriction ) = @_;

    my $prefetch = 
        FixMyStreet::App->model('DB')->schema->storage->sql_maker->quote_char ?
        [ qw/alert_type user/ ] :
        [ qw/alert_type/ ];

    return $rs->search(
        {
            whensubscribed => { '>=', \"current_timestamp-'7 days'::interval" },
            confirmed => 1,
            %{ $restriction },
        },
        {
            prefetch => $prefetch,
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
