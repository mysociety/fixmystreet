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

    my $params = {
        'problem.state' => [ keys %{$args{states}} ],
    };
    $params->{problem_id} = { -not_in => $args{ids} }
        if $args{ids};
    $params->{'problem.category'} = $args{categories} if $args{categories} && @{$args{categories}};

    $params->{$c->stash->{report_age_field}} = { '>=', \"current_timestamp-'$args{report_age}'::interval" }
        if $args{report_age};

    FixMyStreet::DB::ResultSet::Problem->non_public_if_possible($params, $c, 'problem');

    $rs = $c->cobrand->problems_restriction($rs);

    # Add in any optional extra query parameters
    $params = { %$params, %{$args{extra}} } if $args{extra};

    my $attrs = {
        prefetch => { problem => [] },
        bind => [ $args{latitude}, $args{longitude}, $args{distance} ],
        order_by => [ 'distance', { -desc => 'created' } ],
        rows => $args{limit},
    };
    if ($c->user_exists) {
        if ($c->user->from_body || $c->user->is_superuser) {
            push @{$attrs->{prefetch}{problem}}, 'contact';
        }
        if ($c->user->has_body_permission_to('planned_reports')) {
            push @{$attrs->{prefetch}{problem}}, 'user_planned_reports';
        }
        if ($c->user->has_body_permission_to('report_edit_priority') || $c->user->has_body_permission_to('report_inspect')) {
            push @{$attrs->{prefetch}{problem}}, 'response_priority';
        }
    }

    my @problems = mySociety::Locale::in_gb_locale { $rs->search( $params, $attrs )->all };
    return \@problems;
}

1;
