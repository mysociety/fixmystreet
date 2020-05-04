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

sub body_query {
    my ($rs, $bodies) = @_;
    unless (ref $bodies eq 'ARRAY') {
        $bodies = [ map { ref $_ ? $_->id : $_ } $bodies ];
    }
    \[ "regexp_split_to_array(bodies_str, ',') && ?", [ {} => $bodies ] ]
}

# Edits PARAMS in place to either hide non_public reports, or show them
# if user is superuser (all) or inspector (correct body)
sub non_public_if_possible {
    my ($rs, $params, $c) = @_;
    if ($c->user_exists) {
        my $only_non_public = $c->stash->{only_non_public} ? 1 : 0;
        if ($c->user->is_superuser) {
            # See all reports, no restriction
            $params->{non_public} = 1 if $only_non_public;
        } elsif ($c->user->has_body_permission_to('report_inspect') ||
                 $c->user->has_body_permission_to('report_mark_private')) {
            if ($only_non_public) {
                $params->{'-and'} = [
                    non_public => 1,
                    $rs->body_query($c->user->from_body->id),
                ];
            } else {
                $params->{'-or'} = [
                    non_public => 0,
                    $rs->body_query($c->user->from_body->id),
                ];
            }
        } else {
            $params->{non_public} = 0;
        }
    } else {
        $params->{non_public} = 0;
    }
}

sub to_body {
    my ($rs, $bodies, $join) = @_;
    return $rs unless $bodies;
    $join = { join => 'problem' } if $join;
    $rs = $rs->search(
        # This isn't using $rs->body_query because $rs might be Problem, Comment, or Nearby
        FixMyStreet::DB::ResultSet::Problem->body_query($bodies),
        $join
    );
    return $rs;
}

# Front page statistics

sub _cache_timeout {
    FixMyStreet->config('CACHE_TIMEOUT') // 3600;
}

sub recent_fixed {
    my $rs = shift;
    my $key = "recent_fixed:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $rs->search( {
            state => [ FixMyStreet::DB::Result::Problem->fixed_states() ],
            lastupdate => { '>', \"current_timestamp-'1 month'::interval" },
        } )->count;
        Memcached::set($key, $result, _cache_timeout());
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
        Memcached::set($key, $result, _cache_timeout());
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
        Memcached::set($key, $result, _cache_timeout());
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

    # submitted might be returned for e.g. Zurich, but would mean in moderation, so no photo
    my @states = grep { $_ ne 'submitted' } FixMyStreet::DB::Result::Problem->visible_states();
    my $query = {
        non_public => 0,
        state      => \@states,
    };
    $query->{photo} = { '!=', undef } if $photos;

    my $attrs = {
        order_by => { -desc => \'coalesce(confirmed, created)' },
        rows => $num,
    };

    my $probs;
    if (defined $lat) { # No caching
        $attrs->{bind} = [ $lat, $lon, $dist ];
        $attrs->{join} = 'nearby';
        $probs = [ mySociety::Locale::in_gb_locale {
            $rs->search( $query, $attrs )->all;
        } ];
    } else {
        $probs = Memcached::get($key);
        if ($probs) {
            # Need to refetch to check if hidden since cached
            $probs = [ $rs->search({
                id => [ map { $_->id } @$probs ],
                %$query,
            }, $attrs)->all ];
        } else {
            $probs = [ $rs->search( $query, $attrs )->all ];
            Memcached::set($key, $probs, _cache_timeout());
        }
    }

    return $probs;
}

# Problems around a location

sub around_map {
    my ( $rs, $c, %p) = @_;
    my $attr = {
        order_by => $p{order},
    };
    $attr->{rows} = $c->cobrand->reports_per_page;

    unless ( $p{states} ) {
        $p{states} = FixMyStreet::DB::Result::Problem->visible_states();
    }

    my $q = {
            state => [ keys %{$p{states}} ],
            latitude => { '>=', $p{min_lat}, '<', $p{max_lat} },
            longitude => { '>=', $p{min_lon}, '<', $p{max_lon} },
    };

    $q->{$c->stash->{report_age_field}} = { '>=', \"current_timestamp-'$p{report_age}'::interval" } if
        $p{report_age};
    $q->{category} = $p{categories} if $p{categories} && @{$p{categories}};

    $rs->non_public_if_possible($q, $c);

    # Add in any optional extra query parameters
    $q = { %$q, %{$p{extra}} } if $p{extra};

    my $problems = mySociety::Locale::in_gb_locale {
        $rs->search( $q, $attr )->include_comment_counts->page($p{page});
    };
    return $problems;
}

# Admin functions

sub timeline {
    my ( $rs ) = @_;

    return $rs->search(
        {
            -or => {
                'me.created' => { '>=', \"current_timestamp-'7 days'::interval" },
                'me.confirmed' => { '>=', \"current_timestamp-'7 days'::interval" },
                'me.whensent' => { '>=', \"current_timestamp-'7 days'::interval" },
            }
        },
        {
            prefetch => 'user',
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
        columns => [ 'user_id' ],
        distinct => 1,
    } );
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

sub include_comment_counts {
    my $rs = shift;
    my $order_by = $rs->{attrs}{order_by};
    return $rs unless
        (ref $order_by eq 'ARRAY' && ref $order_by->[0] eq 'HASH' && $order_by->[0]->{-desc} eq 'comment_count')
        || (ref $order_by eq 'HASH' && $order_by->{-desc} eq 'comment_count');
    $rs->search({}, {
        '+select' => [ {
            "" => \'(select count(*) from comment where problem_id=me.id and state=\'confirmed\')',
            -as => 'comment_count'
        } ]
    });
}

1;
