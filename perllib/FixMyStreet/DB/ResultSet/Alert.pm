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
            whensubscribed => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
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
            whendisabled => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
            %{ $restriction },
        },
    );
}

1;
