package FixMyStreet::DB::ResultSet::Problem;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub timeline {
    my ( $rs, $restriction ) = @_;

    my $prefetch = 
        FixMyStreet::App->model('DB')->schema->storage->sql_maker->quote_char ?
        [ qw/user/ ] :
        [];

    return $rs->search(
        {
            -or => {
                created  => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
                confirmed => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
                whensent  => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
                %{ $restriction },
            }
        },
        {
            prefetch => $prefetch,
        }
    );
}

sub summary_count {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        $restriction,
        {
            group_by => ['state'],
            select   => [ 'state', { count => 'id' } ],
            as       => [qw/state state_count/]
        }
    );
}

my $site_restriction;
my $site_key;

sub set_restriction {
    my ( $rs, $sql, $key, $restriction ) = @_;
    $site_key = $key;
    $site_restriction = $restriction;
}

sub site_restricted {
    my ( $rs ) = @_;
    return $rs->search( $site_restriction );
}

1;
