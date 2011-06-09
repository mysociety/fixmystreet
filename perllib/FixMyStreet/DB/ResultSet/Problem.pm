package FixMyStreet::DB::ResultSet::Problem;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

my $site_restriction;
my $site_key;

sub set_restriction {
    my ( $rs, $sql, $key, $restriction ) = @_;
    $site_key = $key;
    $site_restriction = $restriction;
}

# Front page statistics

sub recent_fixed {
    my $rs = shift;
    my $key = "recent_fixed:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $rs->search( {
            state => 'fixed',
            lastupdate => { '>', \"current_timestamp-'1 month'::interval" },
        } )->count;
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub recent_new {
    my ( $rs, $interval ) = @_;
    (my $key = $interval) =~ s/\s+//g;
    $key = "recent_new:$site_key:$key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $rs->search( {
            state => [ 'confirmed', 'fixed' ],
            confirmed => { '>', \"current_timestamp-'$interval'::interval" },
        } )->count;
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

# Front page recent lists

sub recent {
    my ( $rs ) = @_;
    my $key = "recent:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $rs->search( {
            state => [ 'confirmed', 'fixed' ]
        }, {
            columns => [ 'id', 'title' ],
            order_by => { -desc => 'confirmed' },
            rows => 5,
        } )->count;
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

# Problems around a location

sub around_map {
    my ( $rs, $min_lat, $max_lat, $min_lon, $max_lon, $interval, $limit ) = @_;
    my $attr = {
        order_by => { -desc => 'created' },
        columns => [
            'id', 'title' ,'latitude', 'longitude', 'state', 'confirmed'
        ],
    };
    $attr->{rows} = $limit if $limit;

    my $q = {
            state => [ 'confirmed', 'fixed' ],
            latitude => { '>=', $min_lat, '<', $max_lat },
            longitude => { '>=', $min_lon, '<', $max_lon },
    };
    $q->{'current_timestamp - lastupdate'} = { '<', \"'$interval'::interval" };

    my @problems = mySociety::Locale::in_gb_locale { $rs->search( $q, $attr )->all };
    return \@problems;
}

# Admin functions

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

1;
