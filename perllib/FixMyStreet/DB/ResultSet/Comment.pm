package FixMyStreet::DB::ResultSet::Comment;
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
            state => 'confirmed',
            created => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
            %{ $restriction },
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
            group_by => ['me.state'],
            select   => [ 'me.state', { count => 'me.id' } ],
            as       => [qw/state state_count/],
            join     => 'problem'
        }
    );
}

1;
