package FixMyStreet::DB::ResultSet::Nearby;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub to_body {
    my ($rs, $bodies) = @_;
    return FixMyStreet::DB::ResultSet::Problem::to_body($rs, $bodies, 1);
}

sub nearby {
    my ( $rs, $c, %args ) = @_;

    unless ( $args{states} ) {
        $args{states} = FixMyStreet::DB::Result::Problem->visible_states();
    }

    my $postgis = FixMyStreet->config('FMS_DB_POSTGIS');
    my ($problem_table, $id_column);
    if ($postgis) {
        $problem_table = 'me';
        $id_column = 'me.id';
    } else {
        $problem_table = 'problem';
        $id_column = 'problem_id';
    }

    my $params = {
        "$problem_table.state" => [ keys %{$args{states}} ],
    };
    $params->{$id_column} = { -not_in => $args{ids} }
        if $args{ids};
    $params->{"$problem_table.category"} = $args{categories} if $args{categories} && @{$args{categories}};

    my $report_age = $args{report_age};
    if ( $report_age && ref $report_age eq 'HASH' ) {
        push @{ $params->{-and} }, FixMyStreet::DB::ResultSet::Problem->report_age_subquery(
            state_table      => $problem_table,
            report_age       => $report_age,
            report_age_field => $c->stash->{report_age_field},
        );
    } elsif ($report_age) {
        $params->{ $c->stash->{report_age_field} }
            = { '>=', \"current_timestamp-'$report_age'::interval" };
    }

    FixMyStreet::DB::ResultSet::Problem->non_public_if_possible($params, $c, $problem_table);

    if ($postgis) {
        return using_postgis($rs, $c, $params, %args);
    } else {
        return using_find_nearby($rs, $c, $params, %args);
    }
}

sub using_postgis {
    my ($rs, $c, $params, %args) = @_;

    my $coord = 'ST_SetSRID(ST_Point(longitude, latitude), 4326)::geography';
    my $point = 'ST_SetSRID(ST_Point(?, ?), 4326)::geography';
    push @{$params->{'-and'}}, \["ST_DWithin($coord, $point, ?)", $args{longitude}, $args{latitude}, $args{distance}*1000 ];
    my $attrs = {
        '+columns' => [
            { distance => \["ST_Distance($coord, $point)", $args{longitude}, $args{latitude}] },
        ],
        # Thanks to https://dba.stackexchange.com/q/310800 and https://neon.com/blog/btree_gist
        # With a gist index on ((st_setsrid(st_point(longitude, latitude), 4326)::geography), extract(epoch from confirmed))
        # and with postgis and btree_gist extensions, you can search 'spatially' by both geography and date
        order_by => [ \[ "($coord <-> $point)", $args{longitude}, $args{latitude} ], \"(extract(epoch from confirmed) <-> extract(epoch from '3000-01-01'::date))" ],
        rows => $args{limit},
    };
    add_prefetch($attrs, $c);

    my @problems = $c->cobrand->problems->search($params, $attrs )->all;

    # And construct Nearby rows as that's what the callers are expecting
    @problems = map { $rs->new_result({ problem => $_, distance => $_->get_column('distance')/1000 }) } @problems;
    return \@problems;
}

sub using_find_nearby {
    my ($rs, $c, $params, %args) = @_;

    my $attrs = {
        join => 'problem',
        bind => [ $args{latitude}, $args{longitude}, $args{distance} ],
        order_by => [ 'distance', { -desc => 'confirmed' } ],
        rows => $args{limit},
    };

    # Construct the query, but do not run it
    my $rs_with_restriction = $c->cobrand->problems_restriction($rs);
    my $query = $rs_with_restriction->search( $params, $attrs )->as_query;
    $query = $$query;

    # Replace the table lookup with it being looked up in a CTE first, as that's much quicker
    my $sql = shift @$query;
    $sql =~ s/problem_find_nearby\(\?,\?,\?\) "me"/"me"/;
    $sql = "WITH me AS MATERIALIZED ( SELECT * FROM problem_find_nearby( ?, ?, ? ) ) $sql";

    # Now perform the query to get the right problem IDs in the right order
    my $storage = $rs->result_source->storage;
    my (undef, $sth, undef) = $storage->dbh_do( _dbh_execute => $sql, $query);
    my $result = $sth->fetchall_arrayref;

    $attrs = {};
    add_prefetch($attrs, $c);

    # Now look up the full rows for the relevant IDs fetched
    my @ids = map { $_->[0] } @$result;
    my @problems = $c->cobrand->problems->search( { 'me.id' => \@ids }, $attrs )->all;

    # And construct Nearby rows as that's what the callers are expecting
    my %problems = map { $_->id => $_ } @problems;
    @problems = map { $rs->new_result({ problem => $problems{$_->[0]}, distance => $_->[1] }) } @$result;
    return \@problems;
}

sub add_prefetch {
    my ($attrs, $c) = @_;

    if ($c->user_exists) {
        if ($c->user->from_body || $c->user->is_superuser) {
            push @{$attrs->{prefetch}}, 'contact';
            $attrs->{join}{contact} = 'translation_category';
            push @{$attrs->{"+columns"}}, { 'contact.msgstr' => \"COALESCE(translation_category.msgstr, contact.category)" };
        }
        if ($c->user->has_body_permission_to('planned_reports')) {
            push @{$attrs->{prefetch}}, 'user_planned_reports';
        }
        if ($c->user->has_body_permission_to('report_edit_priority') || $c->user->has_body_permission_to('report_inspect')) {
            push @{$attrs->{prefetch}}, 'response_priority';
        }
    }
}

1;
