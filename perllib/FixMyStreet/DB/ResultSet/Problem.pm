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
            state => [ FixMyStreet::DB::Result::Problem->fixed_states() ],
            lastupdate => { '>', \"current_timestamp-'1 month'::interval" },
        } )->count;
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub number_comments {
    my $rs = shift;
    my $key = "number_comments:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $rs->search(
            { 'comments.state' => 'confirmed' },
            { join => 'comments' }
        )->count;
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
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
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
    if ( $result ) {
        # Need to reattach schema so that confirmed column gets reinflated.
        $result->[0]->result_source->schema( $rs->result_source->schema ) if $result->[0];
    } else {
        $result = [ $rs->search( {
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ]
        }, {
            columns => [ 'id', 'title', 'confirmed' ],
            order_by => { -desc => 'confirmed' },
            rows => 5,
        } )->all ];
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub recent_photos {
    my ( $rs, $num, $lat, $lon, $dist ) = @_;
    my $probs;
    my $query = {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        photo => { '!=', undef },
    };
    my $attrs = {
        columns => [ 'id', 'title' ],
        order_by => { -desc => 'confirmed' },
        rows => $num,
    };
    if (defined $lat) {
        my $dist2 = $dist; # Create a copy of the variable to stop it being stringified into a locale in the next line!
        my $key = "recent_photos:$site_key:$num:$lat:$lon:$dist2";
        $probs = Memcached::get($key);
        unless ($probs) {
            $attrs->{bind} = [ $lat, $lon, $dist ];
            $attrs->{join} = 'nearby';
            $probs = [ mySociety::Locale::in_gb_locale {
                $rs->search( $query, $attrs )->all;
            } ];
            Memcached::set($key, $probs, 3600);
        }
    } else {
        my $key = "recent_photos:$site_key:$num";
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = [ $rs->search( $query, $attrs )->all ];
            Memcached::set($key, $probs, 3600);
        }
    }
    return $probs;
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
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
            latitude => { '>=', $min_lat, '<', $max_lat },
            longitude => { '>=', $min_lon, '<', $max_lon },
    };
    $q->{'current_timestamp - lastupdate'} = { '<', \"'$interval'::interval" }
        if $interval;

    my @problems = mySociety::Locale::in_gb_locale { $rs->search( $q, $attr )->all };
    return \@problems;
}

# Admin functions

sub timeline {
    my ( $rs ) = @_;

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
            }
        },
        {
            prefetch => $prefetch,
        }
    );
}

sub summary_count {
    my ( $rs ) = @_;

    return $rs->search(
        undef,
        {
            group_by => ['state'],
            select   => [ 'state', { count => 'id' } ],
            as       => [qw/state state_count/]
        }
    );
}

sub unique_users {
    my ( $rs ) = @_;

    return $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
    }, {
        select => [ { count => { distinct => 'user_id' } } ],
        as     => [ 'count' ]
    } )->first->get_column('count');
}

sub categories_summary {
    my ( $rs ) = @_;

    my $fixed_case = "case when state IN ( '" . join( "', '", FixMyStreet::DB::Result::Problem->fixed_states() ) . "' ) then 1 else null end";
    my $categories = $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        whensent => { '<' => \"NOW() - INTERVAL '4 weeks'" },
    }, {
        select   => [ 'category', { count => 'id' }, { count => \$fixed_case } ],
        as       => [ 'category', 'c', 'fixed' ],
        group_by => [ 'category' ],
        result_class => 'DBIx::Class::ResultClass::HashRefInflator'
    } );
    my %categories = map { $_->{category} => { total => $_->{c}, fixed => $_->{fixed} } } $categories->all;
    return \%categories;
}

1;
