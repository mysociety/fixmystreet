package FixMyStreet::DB::ResultSet::Comment;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub to_body {
    my ($rs, $body_restriction) = @_;
    return FixMyStreet::DB::ResultSet::Problem::to_body($rs, $body_restriction);
}


sub timeline {
    my ( $rs, $body_restriction ) = @_;

    my $prefetch = 
        FixMyStreet::App->model('DB')->schema->storage->sql_maker->quote_char ?
        [ qw/user/ ] :
        [];

    return $rs->to_body($body_restriction)->search(
        {
            state => 'confirmed',
            created => { '>=', \"current_timestamp-'7 days'::interval" },
        },
        {
            prefetch => $prefetch,
        }
    );
}

sub summary_count {
    my ( $rs, $body_restriction ) = @_;

    my $params = {
        group_by => ['me.state'],
        select   => [ 'me.state', { count => 'me.id' } ],
        as       => [qw/state state_count/],
    };
    if ($body_restriction) {
        $rs = $rs->to_body($body_restriction);
        $params->{join} = 'problem';
    }
    return $rs->search(undef, $params);
}

1;
