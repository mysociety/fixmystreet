package FixMyStreet::App::Controller::Dashboard;
use Moose;
use namespace::autoclean;

use DateTime;
use Encode;
use JSON::MaybeXS;
use Path::Tiny;
use Time::Piece;
use FixMyStreet::DateRange;
use FixMyStreet::Reporting;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Dashboard - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub auto : Private {
    my ($self, $c) = @_;
    $c->stash->{filter_states} = $c->cobrand->state_groups_inspect;
    return 1;
}

sub example : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'dashboard/index.html';

    $c->stash->{group_by} = 'category+state';

    eval {
        my $j = decode_json(path(FixMyStreet->path_to('data/dashboard.json'))->slurp_utf8);
        $c->stash($j);
    };
    if ($@) {
        my $message = _("There was a problem showing this page. Please try again later.") . ' ' .
            sprintf(_('The error was: %s'), $@);
        $c->detach('/page_error_500_internal_error', [ $message ]);
    }
}

=head2 check_page_allowed

Checks if we can view this page, and if not redirect to 404.

=cut

sub check_page_allowed : Private {
    my ( $self, $c ) = @_;

    # dashboard_permission can return undef (if not present, or to carry on
    # with default behaviour), a body ID to use that body for results, or 0
    # to refuse access entirely
    my $cobrand_check = $c->cobrand->call_hook('dashboard_permission');
    if (defined $cobrand_check) {
        if ($cobrand_check) {
            $cobrand_check = $c->model('DB::Body')->find({ id => $cobrand_check });
        }
        $c->detach( '/page_error_404_not_found' ) if !$cobrand_check;
        return $cobrand_check;
    }

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    my $cobrand_body = $c->cobrand->can('council_area_id') ? $c->cobrand->body : undef;

    my $body;
    if ($c->user->is_superuser) {
        if ($c->get_param('body')) {
            $body = $c->model('DB::Body')->find({ id => $c->get_param('body') });
        } else {
            $body = $cobrand_body;
        }
    } elsif ($c->user->from_body && (!$cobrand_body || $cobrand_body->id == $c->user->from_body->id)) {
        $body = $c->user->from_body;
    } else {
        $c->detach( '/page_error_404_not_found' )
    }
    return $body;
}

=head2 index

Show the summary statistics table.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if ($c->get_param('export')) {
        $c->authenticate(undef, "access_token");
    }

    my $body = $c->stash->{body} = $c->forward('check_page_allowed');

    if ($body) {
        $c->stash->{body_name} = $body->name;

        my $children = $c->stash->{children} = $body->first_area_children;

        $c->forward('/admin/fetch_contacts');
        $c->stash->{contacts} = [ $c->stash->{contacts}->all ];
        $c->forward('/report/stash_category_groups', [ $c->stash->{contacts} ]);

        # See if we've had anything from the body dropdowns
        $c->stash->{category} = $c->get_param('category');
        $c->stash->{ward} = [ $c->get_param_list('ward') ];
        if ($c->user_exists) {
            if (my @areas = @{$c->user->area_ids || []}) {
                $c->stash->{ward} = $c->user->area_ids;
                $c->stash->{body_name} = join " / ", sort map { $children->{$_}->{name} } grep { $children->{$_} } @areas;
            }
        }
    } else {
        my @bodies = $c->model('DB::Body')->search(undef, {
            columns => [ "id", "name" ],
        })->active->translated->with_area_count->all_sorted;
        $c->stash->{ward} = [];
        $c->stash->{bodies} = \@bodies;
    }

    my $days30 = DateTime->now(time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone)->subtract(days => 30);
    $days30->truncate( to => 'day' );

    $c->stash->{start_date} = $c->get_param('start_date') || $days30->strftime('%Y-%m-%d');
    $c->stash->{end_date} = $c->get_param('end_date');
    $c->stash->{q_state} = $c->get_param('state') || '';

    my $reporting = $c->forward('construct_rs_filter', [ $c->get_param('updates') ]);

    if ( my $export = $c->get_param('export') ) {
        $reporting->csv_parameters;
        if ($export == 1) {
            # Existing method, generate and serve
            $reporting->generate_csv_http($c);
        } elsif ($export == 2) {
            # New offline method
            $reporting->kick_off_process;
            my ($redirect, $code) = ('/dashboard/status', 303);
            if (Catalyst::Authentication::Credential::AccessToken->get_token($c)) {
                # Client knows to re-request until ready
                $redirect = '/dashboard/csv/' . $reporting->filename . '.csv';
                $c->res->body('');
                $code = 202;
            }
            $c->res->redirect($redirect, $code);
            $c->detach;
        }
    } else {
        $c->forward('generate_grouped_data');
        $self->generate_summary_figures($c);
    }
}

sub construct_rs_filter : Private {
    my ($self, $c, $updates) = @_;

    my $reporting = FixMyStreet::Reporting->new(
        type => $updates ? 'updates' : 'problems',
        category => $c->stash->{category},
        state => $c->stash->{q_state},
        wards => $c->stash->{ward},
        body => $c->stash->{body} || undef,
        start_date => $c->stash->{start_date},
        end_date => $c->stash->{end_date},
        user => $c->user_exists ? $c->user->obj : undef,
    );

    $c->stash($reporting->construct_rs_filter);
    return $reporting;
}

sub generate_grouped_data : Private {
    my ($self, $c) = @_;

    my $state_map = $c->stash->{state_map} = {};
    $state_map->{$_} = 'open' foreach FixMyStreet::DB::Result::Problem->open_states;
    $state_map->{$_} = 'closed' foreach FixMyStreet::DB::Result::Problem->closed_states;
    $state_map->{$_} = 'fixed' foreach FixMyStreet::DB::Result::Problem->fixed_states;

    my $group_by = $c->get_param('group_by') || $c->stash->{group_by_default} || '';
    my (%grouped, @groups, %totals);
    if ($group_by eq 'category') {
        %grouped = map { $_->category => {} } @{$c->stash->{contacts}};
        @groups = qw/category/;
    } elsif ($group_by eq 'state') {
        @groups = qw/state/;
    } elsif ($group_by eq 'month') {
        @groups = (
                { extract => \"month from confirmed", -as => 'c_month' },
                { extract => \"year from confirmed", -as => 'c_year' },
        );
    } elsif ($group_by eq 'device+site') {
        @groups = qw/cobrand service/;
    } elsif ($group_by eq 'device') {
        @groups = qw/service/;
    } else {
        $group_by = 'category+state';
        @groups = qw/category state/;
        %grouped = map { $_->category => {} } @{$c->stash->{contacts}};
    }
    my $problems = $c->stash->{objects_rs}->search(undef, {
        group_by => [ map { ref $_ ? $_->{-as} : $_ } @groups ],
        select   => [ @groups, { count => 'me.id' } ],
        as       => [ @groups == 2 ? qw/key1 key2 count/ : qw/key1 count/ ],
    } );
    $c->stash->{group_by} = $group_by;

    my %columns;
    while (my $p = $problems->next) {
        my %cols = $p->get_columns;
        my ($col1, $col2) = ($cols{key1}, $cols{key2});
        if ($group_by eq 'category+state') {
            $col2 = $state_map->{$cols{key2}};
        } elsif ($group_by eq 'month') {
            $col1 = Time::Piece->strptime("2017-$cols{key1}-01", '%Y-%m-%d')->fullmonth;
        }
        $grouped{$col1}->{$col2} += $cols{count} if defined $col2;
        $grouped{$col1}->{total} += $cols{count};
        $totals{$col2} += $cols{count} if defined $col2;
        $totals{total} += $cols{count};
        $columns{$col2} = 1 if defined $col2;
    }

    my @columns = keys %columns;
    my @rows = keys %grouped;
    if ($group_by eq 'month') {
        my %months;
        my @months = qw/January February March April May June
            July August September October November December/;
        @months{@months} = (0..11);
        @rows = sort { $months{$a} <=> $months{$b} } @rows;
    } elsif ($group_by eq 'state') {
        my $state_map = $c->stash->{state_map};
        my %map = (confirmed => 0, open => 1, fixed => 2, closed => 3);
        @rows = sort {
            my $am = $map{$a} // $map{$state_map->{$a}};
            my $bm = $map{$b} // $map{$state_map->{$b}};
            $am <=> $bm;
        } @rows;
    } else {
        @rows = sort @rows;
    }
    $c->stash->{rows} = \@rows;
    $c->stash->{columns} = \@columns;

    $c->stash->{grouped} = \%grouped;
    $c->stash->{totals} = \%totals;
}

sub generate_summary_figures {
    my ($self, $c) = @_;
    my $state_map = $c->stash->{state_map};

    # problems this month by state
    $c->stash->{"summary_$_"} = 0 for values %$state_map;

    $c->stash->{summary_open} = $c->stash->{objects_rs}->count;

    my $params = $c->stash->{params};
    $params = { map { my $n = $_; s/me\./problem\./ unless /me\.confirmed/; $_ => $params->{$n} } keys %$params };

    my $comments = $c->model('DB::Comment')->to_body(
        $c->stash->{body}
    )->search(
        {
            %$params,
            'me.id' => { 'in' => \"(select min(id) from comment where me.problem_id=comment.problem_id and problem_state not in ('', 'confirmed') group by problem_state)" },
        },
        {
            join     => 'problem',
            group_by => [ 'problem_state' ],
            select   => [ 'problem_state', { count => 'me.id' } ],
            as       => [ qw/problem_state count/ ],
        }
    );

    while (my $comment = $comments->next) {
        my $meta_state = $state_map->{$comment->problem_state};
        next if $meta_state eq 'open';
        $c->stash->{"summary_$meta_state"} += $comment->get_column('count');
    }
}

sub status : Local : Args(0) {
    my ($self, $c) = @_;

    my $body = $c->stash->{body} = $c->forward('check_page_allowed');
    $c->stash->{body_name} = $body->name if $body;

    my $reporting = FixMyStreet::Reporting->new(
        user => $c->user_exists ? $c->user->obj : undef,
    );
    my $dir = $reporting->cache_dir;
    my @data;
    foreach ($dir->children) {
        my $stat = $_->stat;
        my $name = $_->basename;
        my $finished = $name =~ /part$/ ? 0 : 1;
        $name =~ s/-part$//;
        push @data, {
            ctime => $stat->ctime,
            size => $stat->size,
            name => $name,
            finished => $finished,
        };
    }
    @data = sort { $b->{ctime} <=> $a->{ctime} } @data;
    $c->stash->{rows} = \@data;
}

sub csv : Local : Args(1) {
    my ($self, $c, $filename) = @_;

    $c->authenticate(undef, "access_token");

    my $body = $c->stash->{body} = $c->forward('check_page_allowed');

    (my $basename = $filename) =~ s/\.csv$//;
    my $reporting = FixMyStreet::Reporting->new(
        user => $c->user_exists ? $c->user->obj : undef,
        filename => $basename,
    );
    my $dir = $reporting->cache_dir;
    my $csv = path($dir, $filename);

    if (!$csv->exists) {
        if (path($dir, "$filename-part")->exists && Catalyst::Authentication::Credential::AccessToken->get_token($c)) {
            $c->res->body('');
            $c->res->status(202);
            $c->detach;
        } else {
            $c->detach( '/page_error_404_not_found', [] ) unless $csv->exists;
        }
    }

    $reporting->http_setup($c);
    $c->res->body($csv->openr_raw);
}

sub generate_body_response_time : Private {
    my ( $self, $c ) = @_;

    my $avg = $c->stash->{body}->calculate_average($c->cobrand->call_hook("body_responsiveness_threshold"));
    $c->stash->{body_average} = $avg ? int($avg / 60 / 60 / 24 + 0.5) : 0;
}

sub heatmap : Local : Args(0) {
    my ($self, $c) = @_;

    my $body = $c->stash->{body} = $c->forward('check_page_allowed');
    $c->detach( '/page_error_404_not_found' )
        unless $body && $c->cobrand->feature('heatmap');

    $c->stash->{page} = 'reports'; # So the map knows to make clickable pins

    my @wards = $c->get_param_list('wards', 1);
    $c->forward('/reports/ward_check', [ @wards ]) if @wards;
    $c->forward('/reports/stash_report_filter_status');
    $c->forward('/reports/stash_report_sort', [ $c->cobrand->reports_ordering ]); # Not actually used
    my $parameters = $c->forward( '/reports/load_problems_parameters');

    my $where = $parameters->{where};
    my $filter = $parameters->{filter};
    delete $filter->{rows};

    $c->forward('heatmap_filters', [ $where ]);

    # Load the relevant stuff for the sidebar as well
    my $problems = $c->cobrand->problems;
    $problems = $problems->to_body($body);
    $problems = $problems->search($where, $filter);

    $c->forward('heatmap_sidebar', [ $problems, $where ]);

    if ($c->get_param('ajax')) {
        my @pins;
        while ( my $problem = $problems->next ) {
            push @pins, $problem->pin_data('reports');
        }
        $c->stash->{pins} = \@pins;
        $c->detach('/reports/ajax', [ 'dashboard/heatmap-list.html' ]);
    }

    my $children = $c->stash->{body}->first_area_children;
    $c->stash->{children} = $children;
    $c->stash->{ward_hash} = { map { $_->{id} => 1 } @{$c->stash->{wards}} } if $c->stash->{wards};

    $c->forward('/reports/setup_categories');
    $c->forward('/reports/setup_map');
}

sub heatmap_filters :Private {
    my ($self, $c, $where) = @_;

    # Wards
    if ($c->user_exists) {
        my @areas = @{$c->user->area_ids || []};
        # Want to get everything if nothing given in an ajax call
        if (!$c->stash->{wards} && @areas) {
            $c->stash->{wards} = [ map { { id => $_ } } @areas ];
            $where->{areas} = [
                map { { 'like', '%,' . $_ . ',%' } } @areas
            ];
        }
    }

    # Date range
    my $start_default = DateTime->today(time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone)->subtract(months => 1);
    $c->stash->{start_date} = $c->get_param('start_date') || $start_default->strftime('%Y-%m-%d');
    $c->stash->{end_date} = $c->get_param('end_date');

    my $range = FixMyStreet::DateRange->new(
        start_date => $c->stash->{start_date},
        start_default => $start_default,
        end_date => $c->stash->{end_date},
        formatter => $c->model('DB')->storage->datetime_parser,
    );
    $where->{'me.confirmed'} = $range->sql;
}

sub heatmap_sidebar :Private {
    my ($self, $c, $problems, $where) = @_;

    $c->stash->{five_newest} = [ $problems->search(undef, {
        rows => 5,
        order_by => { -desc => 'confirmed' },
    })->all ];

    $c->stash->{ten_oldest} = [ $problems->search({
        'me.state' => [ FixMyStreet::DB::Result::Problem->open_states() ],
    }, {
        rows => 10,
        order_by => 'lastupdate',
    })->all ];

    my $params = { map {
        my $v = $where->{$_};
        if (ref $v eq 'HASH') {
            $v = { map { my $vv = $v->{$_}; s/me\./problem\./; $_ => $vv } keys %$v };
        } else {
            s/me\./problem\./;
        }
        $_ => $v;
    } keys %$where };
    my $body = $c->stash->{body};

    my @user;
    push @user, $c->user->id if $c->user_exists;
    push @user, $body->comment_user_id if $body->comment_user_id;
    $params->{'me.user_id'} = { -not_in => \@user } if @user;

    my @c = $c->model('DB::Comment')->to_body($body)->search({
        %$params,
        'me.state' => 'confirmed',
    }, {
        columns => 'problem_id',
        group_by => 'problem_id',
        order_by => { -desc => \'max(me.confirmed)' },
        rows => 5,
    })->all;
    $c->stash->{five_commented} = [ map { $_->problem } @c ];
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2017 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;

