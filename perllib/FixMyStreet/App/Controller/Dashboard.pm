package FixMyStreet::App::Controller::Dashboard;
use Moose;
use namespace::autoclean;

use DateTime;
use JSON::MaybeXS;
use Path::Tiny;
use Text::CSV;
use Time::Piece;

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

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    $c->detach( '/page_error_404_not_found' )
        unless $c->user->from_body || $c->user->is_superuser;

    my $body = $c->user->from_body;
    if (!$body && $c->get_param('body')) {
        # Must be a superuser, so allow query parameter if given
        $body = $c->model('DB::Body')->find({ id => $c->get_param('body') });
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

        # See if we've had anything from the body dropdowns
        $c->stash->{category} = $c->get_param('category');
        $c->stash->{ward} = $c->get_param('ward');
        if ($c->user->area_id) {
            $c->stash->{ward} = $c->user->area_id;
            $c->stash->{body_name} = join "", map { $children->{$_}->{name} } grep { $children->{$_} } $c->user->area_id;
        }
    } else {
        my @bodies = $c->model('DB::Body')->active->translated->with_area_count->all_sorted;
        $c->stash->{bodies} = \@bodies;
    }

    my $days30 = DateTime->now(time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone)->subtract(days => 30);
    $days30->truncate( to => 'day' );

    $c->stash->{start_date} = $c->get_param('start_date') || $days30->strftime('%Y-%m-%d');
    $c->stash->{end_date} = $c->get_param('end_date');
    $c->stash->{q_state} = $c->get_param('state') || '';

    $c->forward('construct_rs_filter');

    if ( $c->get_param('export') ) {
        $c->forward('export_as_csv');
    } else {
        $c->forward('generate_grouped_data');
        $self->generate_summary_figures($c);
    }
}

sub construct_rs_filter : Private {
    my ($self, $c) = @_;

    my %where;
    $where{areas} = { 'like', '%,' . $c->stash->{ward} . ',%' }
        if $c->stash->{ward};
    $where{category} = $c->stash->{category}
        if $c->stash->{category};

    my $state = $c->stash->{q_state};
    if ( FixMyStreet::DB::Result::Problem->fixed_states->{$state} ) { # Probably fixed - council
        $where{'me.state'} = [ FixMyStreet::DB::Result::Problem->fixed_states() ];
    } elsif ( $state ) {
        $where{'me.state'} = $state;
    } else {
        $where{'me.state'} = [ FixMyStreet::DB::Result::Problem->visible_states() ];
    }

    my $dtf = $c->model('DB')->storage->datetime_parser;

    my $start_date = $dtf->parse_datetime($c->stash->{start_date});
    $where{'me.confirmed'} = { '>=', $dtf->format_datetime($start_date) };

    if (my $end_date = $c->stash->{end_date}) {
        my $one_day = DateTime::Duration->new( days => 1 );
        $end_date = $dtf->parse_datetime($end_date) + $one_day;
        $where{'me.confirmed'} = [ -and => $where{'me.confirmed'}, { '<', $dtf->format_datetime($end_date) } ];
    }

    $c->stash->{params} = \%where;
    $c->stash->{problems_rs} = $c->cobrand->problems->to_body($c->stash->{body})->search( \%where );
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
    my $problems = $c->stash->{problems_rs}->search(undef, {
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

    $c->stash->{summary_open} = $c->stash->{problems_rs}->count;

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

sub generate_body_response_time : Private {
    my ( $self, $c ) = @_;

    my $avg = $c->stash->{body}->calculate_average;
    $c->stash->{body_average} = $avg ? int($avg / 60 / 60 / 24 + 0.5) : 0;
}

sub export_as_csv : Private {
    my ($self, $c) = @_;

    my $csv = $c->stash->{csv} = {
        problems => $c->stash->{problems_rs}->search_rs({}, {
            prefetch => 'comments',
            order_by => ['me.confirmed', 'me.id'],
        }),
        headers => [
            'Report ID',
            'Title',
            'Detail',
            'User Name',
            'Category',
            'Created',
            'Confirmed',
            'Acknowledged',
            'Fixed',
            'Closed',
            'Status',
            'Latitude', 'Longitude',
            'Query',
            'Ward',
            'Easting',
            'Northing',
            'Report URL',
        ],
        columns => [
            'id',
            'title',
            'detail',
            'user_name_display',
            'category',
            'created',
            'confirmed',
            'acknowledged',
            'fixed',
            'closed',
            'state',
            'latitude', 'longitude',
            'postcode',
            'wards',
            'local_coords_x',
            'local_coords_y',
            'url',
        ],
        filename => do {
            my %where = (
                category => $c->stash->{category},
                state    => $c->stash->{q_state},
                ward     => $c->stash->{ward},
            );
            $where{body} = $c->stash->{body}->id if $c->stash->{body};
            join '-',
                $c->req->uri->host,
                map {
                    my $value = $where{$_};
                    (defined $value and length $value) ? ($_, $value) : ()
                } sort keys %where
        },
    };
    $c->cobrand->call_hook("dashboard_export_add_columns");
    $c->forward('generate_csv');
}

=head2 generate_csv

Generates a CSV output, given a 'csv' stash hashref containing:
* filename: filename to be used in output
* problems: a resultset of the rows to output
* headers: an arrayref of the header row strings
* columns: an arrayref of the columns (looked up in the row's as_hashref, plus
the following: user_name_display, acknowledged, fixed, closed, wards,
local_coords_x, local_coords_y, url).
* extra_data: If present, a function that is passed the report and returns a
hashref of extra data to include that can be used by 'columns'.

=cut

sub generate_csv : Private {
    my ($self, $c) = @_;

    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    $csv->combine(@{$c->stash->{csv}->{headers}});
    my @body = ($csv->string);

    my $fixed_states = FixMyStreet::DB::Result::Problem->fixed_states;
    my $closed_states = FixMyStreet::DB::Result::Problem->closed_states;

    my %asked_for = map { $_ => 1 } @{$c->stash->{csv}->{columns}};

    my $problems = $c->stash->{csv}->{problems};
    while ( my $report = $problems->next ) {
        my $hashref = $report->as_hashref($c, \%asked_for);

        $hashref->{user_name_display} = $report->anonymous
            ? '(anonymous)' : $report->name;

        if ($asked_for{acknowledged}) {
            for my $comment ($report->comments) {
                my $problem_state = $comment->problem_state or next;
                next unless $comment->state eq 'confirmed';
                next if $problem_state eq 'confirmed';
                $hashref->{acknowledged} //= $comment->confirmed;
                $hashref->{fixed} //= $fixed_states->{ $problem_state } || $comment->mark_fixed ?
                    $comment->confirmed : undef;
                if ($closed_states->{ $problem_state }) {
                    $hashref->{closed} = $comment->confirmed;
                    last;
                }
            }
        }

        if ($asked_for{wards}) {
            $hashref->{wards} = join ', ',
              map { $c->stash->{children}->{$_}->{name} }
              grep {$c->stash->{children}->{$_} }
              split ',', $hashref->{areas};
        }

        ($hashref->{local_coords_x}, $hashref->{local_coords_y}) =
            $report->local_coords;
        $hashref->{url} = join '', $c->cobrand->base_url_for_report($report), $report->url;

        if (my $fn = $c->stash->{csv}->{extra_data}) {
            my $extra = $fn->($report);
            $hashref = { %$hashref, %$extra };
        }

        $csv->combine(
            @{$hashref}{
                @{$c->stash->{csv}->{columns}}
            },
        );

        push @body, $csv->string;
    }

    my $filename = $c->stash->{csv}->{filename};
    $c->res->content_type('text/csv; charset=utf-8');
    $c->res->header('content-disposition' => "attachment; filename=${filename}.csv");
    $c->res->body( join "", @body );
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2017 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;

