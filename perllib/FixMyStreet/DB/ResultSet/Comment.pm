package FixMyStreet::DB::ResultSet::Comment;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub to_body {
    my ($rs, $bodies) = @_;
    return FixMyStreet::DB::ResultSet::Problem::to_body($rs, $bodies, 1);
}


sub timeline {
    my ( $rs ) = @_;

    return $rs->search(
        {
            'me.state' => 'confirmed',
            'me.created' => { '>=', \"current_timestamp-'7 days'::interval" },
        },
        {
            prefetch => 'user',
        }
    );
}

sub summary_count {
    my ( $rs ) = @_;

    my $params = {
        group_by => ['me.state'],
        select   => [ 'me.state', { count => 'me.id' } ],
        as       => [qw/state state_count/],
    };
    return $rs->search(undef, $params);
}

1;
