package FixMyStreet::DB::ResultSet::Comment;
use base 'FixMyStreet::DB::ResultSet';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::DB::FullTextSearch';
__PACKAGE__->load_components('Helper::ResultSet::Me');
sub text_search_columns { qw(id problem_id name text) }
sub text_search_nulls { qw(name) }
sub text_search_translate { '/.' }

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
