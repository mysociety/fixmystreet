package FixMyStreet::DB::ResultSet::Problem;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

use Memcached;
use mySociety::Locale;
use FixMyStreet::DB;

my $site_key;

sub set_restriction {
    my ( $rs, $key ) = @_;
    $site_key = $key;
}

sub to_body {
    my ($rs, $bodies, $join) = @_;
    return $rs unless $bodies;
    unless (ref $bodies eq 'ARRAY') {
        $bodies = [ map { ref $_ ? $_->id : $_ } $bodies ];
    }
    $join = { join => 'problem' } if $join;
    $rs = $rs->search(
        \[ "regexp_split_to_array(bodies_str, ',') && ?", [ {} => $bodies ] ],
        $join
    );
    return $rs;
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
    return _recent( $rs, 5 );
}

sub recent_photos {
    my ( $rs, $num, $lat, $lon, $dist ) = @_;
    return _recent( $rs, $num, $lat, $lon, $dist, 1);
}

sub _recent {
    my ( $rs, $num, $lat, $lon, $dist, $photos ) = @_;

    my $key = $photos ? 'recent_photos' : 'recent';
    $key .= ":$site_key:$num";

    # unconfirmed might be returned for e.g. Zurich, but would mean in moderation, so no photo
    my @states = grep { $_ ne 'unconfirmed' } FixMyStreet::DB::Result::Problem->visible_states();
    my $query = {
        non_public => 0,
        state      => \@states,
    };
    $query->{photo} = { '!=', undef } if $photos;

    my $attrs = {
        order_by => { -desc => 'coalesce(confirmed, created)' },
        rows => $num,
    };

    my $probs;
    my $new = 0;
    if (defined $lat) {
        my $dist2 = $dist; # Create a copy of the variable to stop it being stringified into a locale in the next line!
        $key .= ":$lat:$lon:$dist2";
        $probs = Memcached::get($key);
        unless ($probs) {
            $attrs->{bind} = [ $lat, $lon, $dist ];
            $attrs->{join} = 'nearby';
            $probs = [ mySociety::Locale::in_gb_locale {
                $rs->search( $query, $attrs )->all;
            } ];
            $new = 1;
        }
    } else {
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = [ $rs->search( $query, $attrs )->all ];
            $new = 1;
        }
    }

    if ( $new ) {
        Memcached::set($key, $probs, 3600);
    } else {
        # Need to reattach schema so that confirmed column gets reinflated.
        $probs->[0]->result_source->schema( $rs->result_source->schema ) if $probs->[0];
    }

    return $probs;
}

# Problems around a location

sub around_map {
    my ( $rs, $min_lat, $max_lat, $min_lon, $max_lon, $interval, $limit, $category, $states ) = @_;
    my $attr = {
        order_by => { -desc => 'created' },
    };
    $attr->{rows} = $limit if $limit;

    unless ( $states ) {
        $states = FixMyStreet::DB::Result::Problem->visible_states();
    }

    my $q = {
            non_public => 0,
            state => [ keys %$states ],
            latitude => { '>=', $min_lat, '<', $max_lat },
            longitude => { '>=', $min_lon, '<', $max_lon },
    };
    $q->{'current_timestamp - lastupdate'} = { '<', \"'$interval'::interval" }
        if $interval;
    $q->{category} = $category if $category;

    my @problems = mySociety::Locale::in_gb_locale { $rs->search( $q, $attr )->all };
    return \@problems;
}

# Admin functions

sub timeline {
    my ( $rs ) = @_;

    my $prefetch =
        $rs->result_source->storage->sql_maker->quote_char ?
        [ qw/user/ ] :
        [];

    return $rs->search(
        {
            -or => {
                created  => { '>=', \"current_timestamp-'7 days'::interval" },
                confirmed => { '>=', \"current_timestamp-'7 days'::interval" },
                whensent  => { '>=', \"current_timestamp-'7 days'::interval" },
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
        select => [ { distinct => 'user_id' } ],
        as     => [ 'user_id' ]
    } )->as_subselect_rs->search( undef, {
        select => [ { count => 'user_id' } ],
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

sub send_reports {
    my ( $rs, $site_override ) = @_;
    require FixMyStreet::Script::Reports;
    FixMyStreet::Script::Reports::send($site_override);
}

1;
