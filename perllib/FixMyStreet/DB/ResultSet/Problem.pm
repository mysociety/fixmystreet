package FixMyStreet::DB::ResultSet::Problem;
use base 'FixMyStreet::DB::ResultSet';

use strict;
use warnings;

use Memcached;
use mySociety::Locale;
use FixMyStreet::DB;

use Moo;
with 'FixMyStreet::Roles::DB::FullTextSearch';
__PACKAGE__->load_components('Helper::ResultSet::Me');
sub text_search_columns { qw(id external_id bodies_str name title detail) }
sub text_search_nulls { qw(external_id bodies_str) }
sub text_search_translate { '/.' }

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
    my ($rs, $params, $c, $table) = @_;
    $table ||= 'me';
    if ($c->user_exists) {
        my $only_non_public = $c->stash->{only_non_public} ? 1 : 0;
        if ($c->user->is_superuser) {
            # See all reports, no restriction
            $params->{"$table.non_public"} = 1 if $only_non_public;
        } elsif ($c->user->has_body_permission_to('report_inspect') ||
                 $c->user->has_body_permission_to('report_mark_private')) {
            if ($only_non_public) {
                push @{ $params->{-and} }, {
                    -and => [
                        "$table.non_public" => 1,
                        $rs->body_query($c->user->from_body->id),
                    ]
                };
            } else {
                push @{ $params->{-and} }, {
                    -or => [
                        "$table.non_public" => 0,
                        $rs->body_query( $c->user->from_body->id ),
                    ]
                };
            }
        } else {
            $params->{"$table.non_public"} = 0;
        }
    } else {
        $params->{"$table.non_public"} = 0;
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
    my $timeout = FixMyStreet->config('CACHE_TIMEOUT') // 3600;
    # Spread it out a bit
    $timeout = $timeout * (0.75 + rand()/2);
    return $timeout;
}

sub recent_completed {
    my $rs = shift;
    $rs->_recent_in_states('completed', [
        FixMyStreet::DB::Result::Problem->fixed_states(),
        FixMyStreet::DB::Result::Problem->closed_states()
    ]);
}

sub recent_fixed {
    my $rs = shift;
    $rs->_recent_in_states('fixed', [ FixMyStreet::DB::Result::Problem->fixed_states() ]);
}

sub _recent_in_states {
    my ($rs, $state_key, $states) = @_;
    return $rs->search( {
        state => $states,
        lastupdate => { '>', \"current_timestamp-'1 month'::interval" },
    } )->count;
}

sub number_comments {
    my $rs = shift;
    return $rs->search(
        { 'comments.state' => 'confirmed' },
        { join => 'comments' }
    )->count;
}

sub recent_new {
    my ( $rs, $interval ) = @_;
    return $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        confirmed => { '>', \"current_timestamp-'$interval'::interval" },
    } )->count;
}

# Front page recent lists

sub recent {
    my ( $rs ) = @_;
    return _recent($rs, { num => 5 });
}

sub recent_photos {
    my ( $rs, $params ) = @_;
    return _recent($rs, { %$params, photos => 1 });
}

sub _recent {
    my ( $rs, $params ) = @_;

    my $key = $params->{photos} ? 'recent_photos' : 'recent';
    $key .= ":$params->{extra_key}" if $params->{extra_key};
    $key .= ":$site_key:$params->{num}";

    if ($params->{bodies}) {
        $rs = $rs->to_body($params->{bodies});
    }

    # submitted might be returned for e.g. Zurich, but would mean in moderation, so no photo
    my @states = grep { $_ ne 'submitted' } FixMyStreet::DB::Result::Problem->visible_states();
    my $query = {
        non_public => 0,
        state      => \@states,
    };
    $query->{photo} = { '!=', undef } if $params->{photos};

    my $attrs = {
        # We order by most recently _created_, not confirmed, as the latter
        # is too slow on installations with millions of reports.
        # The correct ordering is applied by the `sort` lines below.
        order_by => { -desc => 'id' },
        rows => $params->{num},
    };

    my $probs;
    if (defined $params->{point}->[0]) { # No caching
        $attrs->{bind} = $params->{point};
        $attrs->{join} = 'nearby';
        $probs = [ mySociety::Locale::in_gb_locale {
            sort { _cmp_reports($b, $a) } $rs->search( $query, $attrs )->all;
        } ];
    } else {
        $probs = Memcached::get($key) unless FixMyStreet->test_mode;
        if ($probs) {
            # Need to refetch to check if hidden since cached
            $probs = [ sort { _cmp_reports($b, $a) } $rs->search({
                id => [ map { $_->id } @$probs ],
                %$query,
            }, $attrs)->all ];
        } else {
            $probs = [ sort { _cmp_reports($b, $a) } $rs->search( $query, $attrs )->all ];
            Memcached::set($key, $probs, _cache_timeout());
        }
    }

    return $probs;
}

sub _cmp_reports {
    my ($a, $b) = @_;

    # reports may not be confirmed
    my $a_confirmed = $a->confirmed ? $a->confirmed->epoch : 0;
    my $b_confirmed = $b->confirmed ? $b->confirmed->epoch : 0;

    return $a_confirmed <=> $b_confirmed;
}


# Problems around a location

sub around_map {
    my ( $rs, $c, %p) = @_;
    my $attr = {
        order_by => $p{order},
        rows => $c->cobrand->reports_per_page,
    };
    if ($c->user_exists) {
        if ($c->user->from_body || $c->user->is_superuser) {
            push @{$attr->{prefetch}}, 'contact';
            $attr->{join}{contact} = 'translation_category';
            push @{$attr->{"+columns"}}, { 'contact.msgstr' => \"COALESCE(translation_category.msgstr, contact.category)" };
        }
        if ($c->user->has_body_permission_to('planned_reports')) {
            push @{$attr->{prefetch}}, 'user_planned_reports';
        }
        if ($c->user->has_body_permission_to('report_edit_priority') || $c->user->has_body_permission_to('report_inspect')) {
            push @{$attr->{prefetch}}, 'response_priority';
        }
    }

    unless ( $p{states} ) {
        $p{states} = FixMyStreet::DB::Result::Problem->visible_states();
    }

    my $q = {
            'me.state' => [ keys %{$p{states}} ],
            latitude => { '>=', $p{min_lat}, '<', $p{max_lat} },
            longitude => { '>=', $p{min_lon}, '<', $p{max_lon} },
    };

    my $report_age = $p{report_age};
    if ( $report_age && ref $report_age eq 'HASH' ) {
        push @{ $q->{-and} }, __PACKAGE__->report_age_subquery(
            state_table      => 'me',
            report_age       => $report_age,
            report_age_field => $c->stash->{report_age_field},
        );
    } elsif ($report_age) {
        $q->{ $c->stash->{report_age_field} }
            = { '>=', \"current_timestamp-'$report_age'::interval" };
    }

    $q->{'me.category'} = $p{categories} if $p{categories} && @{$p{categories}};

    $rs->non_public_if_possible($q, $c);

    # Add in any optional extra query parameters
    $q = { %$q, %{$p{extra}} } if $p{extra};

    my $problems = mySociety::Locale::in_gb_locale {
        $rs->search( $q, $attr )->include_comment_counts->page($p{page});
    };
    return $problems;
}

sub report_age_subquery {
    my ( $self, %args ) = @_;

    my @possible_states = (qw/open closed fixed/);
    my $default_time = FixMyStreet::Cobrand::Default->report_age;
    my $sub_q = [];

    for my $state ( @possible_states ) {
        # Call relevant function to get substates
        my $call = "${state}_states";
        my @substates = FixMyStreet::DB::Result::Problem->$call;

        my $time = $args{report_age}{$state} // $default_time;
        my %time_q;
        if (ref $time eq 'HASH') {
            # Gloucestershire have special settings for Confirm jobs
            for my $type ( qw/job enquiry/ ) {
                my %type_q;
                if ( $type eq 'job' ) {
                    %type_q = ( "$args{state_table}.external_id" => { '-like' => 'JOB_%' } );
                } else {
                    %type_q = (
                        "$args{state_table}.external_id" => [
                            { '=', undef },
                            { '-not_like' => 'JOB_%' },
                        ],
                    );
                }

                my $time_str = $time->{$type} // $default_time;
                push @$sub_q, {
                    "$args{state_table}.state" => { '-in' => \@substates },
                    $args{report_age_field}    => { '>=' => \"current_timestamp-'$time_str'::interval" },
                    %type_q,
                };
            }
        } else {
            push @$sub_q, {
                "$args{state_table}.state" => { '-in' => \@substates },
                $args{report_age_field}    => { '>=' => \"current_timestamp-'$time'::interval" },
            };
        }
    }

    return { -or => $sub_q };
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
