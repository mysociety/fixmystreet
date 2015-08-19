package FixMyStreet::App::Controller::Dashboard;
use Moose;
use namespace::autoclean;

use DateTime;
use File::Slurp;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Dashboard - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub example : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'dashboard/index.html';

    $c->stash->{children} = {};
    for my $i (1..3) {
        $c->stash->{children}{$i} = { id => $i, name => "Ward $i" };
    }

    # TODO Set up manual version of what the below would do
    #$c->forward( '/report/new/setup_categories_and_bodies' );

    # See if we've had anything from the dropdowns - perhaps vary results if so
    $c->stash->{ward} = $c->get_param('ward');
    $c->stash->{category} = $c->get_param('category');
    $c->stash->{q_state} = $c->get_param('state');

    eval {
        my $data = File::Slurp::read_file(
            FixMyStreet->path_to( 'data/dashboard.json' )->stringify
        );
        my $j = JSON->new->utf8->decode($data);
        if ( !$c->stash->{ward} && !$c->stash->{category} ) {
            $c->stash->{problems} = $j->{counts_all};
        } else {
            $c->stash->{problems} = $j->{counts_some};
        }
        $c->stash->{council} = $j->{council};
        $c->stash->{children} = $j->{wards};
        $c->stash->{category_options} = $j->{category_options};
        if ( lc($c->stash->{q_state}) eq 'all' or !$c->stash->{q_state} ) {
            $c->stash->{lists} = $j->{lists}->{all};
        } else {
            $c->stash->{lists} = $j->{lists}->{filtered};
        }
    };
    if ($@) {
        $c->stash->{message} = _("There was a problem showing this page. Please try again later.") . ' ' .
            sprintf(_('The error was: %s'), $@);
        $c->stash->{template} = 'errors/generic.html';
    }
}

=head2 check_page_allowed

Checks if we can view this page, and if not redirect to 404.

=cut

sub check_page_allowed : Private {
    my ( $self, $c ) = @_;

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    $c->detach( '/page_error_404_not_found' )
        unless $c->user_exists && $c->user->from_body;

    return $c->user->from_body;
}

=head2 index

Show the dashboard table.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $body = $c->forward('check_page_allowed');
    $c->stash->{body} = $body;

    # Set up the data for the dropdowns

    # Just take the first area ID we find
    my $area_id = $body->body_areas->first->area_id;

    my $council_detail = mySociety::MaPit::call('area', $area_id );
    $c->stash->{council} = $council_detail;

    my $children = mySociety::MaPit::call('area/children', $area_id,
        type => $c->cobrand->area_types_children,
    );
    $c->stash->{children} = $children;

    $c->stash->{all_areas} = { $area_id => $council_detail };
    $c->forward( '/report/new/setup_categories_and_bodies' );

    # See if we've had anything from the dropdowns

    $c->stash->{ward} = $c->get_param('ward');
    $c->stash->{category} = $c->get_param('category');

    my %where = (
        'problem.state' => [ FixMyStreet::DB::Result::Problem->visible_states() ],
    );
    $where{areas} = { 'like', '%,' . $c->stash->{ward} . ',%' }
        if $c->stash->{ward};
    $where{category} = $c->stash->{category}
        if $c->stash->{category};
    $c->stash->{where} = \%where;
    my $prob_where = { %where };
    $prob_where->{'me.state'} = $prob_where->{'problem.state'};
    delete $prob_where->{'problem.state'};
    $c->stash->{prob_where} = $prob_where;

    my $dtf = $c->model('DB')->storage->datetime_parser;

    my %counts;
    my $now = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $t = $now->clone->truncate( to => 'day' );
    $counts{wtd} = $c->forward( 'updates_search',
        [ $dtf->format_datetime( $t->clone->subtract( days => $t->dow - 1 ) ) ] );
    $counts{week} = $c->forward( 'updates_search',
        [ $dtf->format_datetime( $now->clone->subtract( weeks => 1 ) ) ] );
    $counts{weeks} = $c->forward( 'updates_search',
        [ $dtf->format_datetime( $now->clone->subtract( weeks => 4 ) ) ] );
    $counts{ytd} = $c->forward( 'updates_search',
        [ $dtf->format_datetime( $t->clone->set( day => 1, month => 1 ) ) ] );

    $c->stash->{problems} = \%counts;

    # List of reports underneath summary table

    $c->stash->{q_state} = $c->get_param('state') || '';
    if ( $c->stash->{q_state} eq 'fixed' ) {
        $prob_where->{'me.state'} = [ FixMyStreet::DB::Result::Problem->fixed_states() ];
    } elsif ( $c->stash->{q_state} ) {
        $prob_where->{'me.state'} = $c->stash->{q_state};
        $prob_where->{'me.state'} = { IN => [ 'planned', 'action scheduled' ] }
            if $prob_where->{'me.state'} eq 'action scheduled';
    }
    my $params = {
        %$prob_where,
        'me.confirmed' => { '>=', $dtf->format_datetime( $now->clone->subtract( days => 30 ) ) },
    };
    my $problems_rs = $c->cobrand->problems->to_body($body)->search( $params );
    my @problems = $problems_rs->all;

    my %problems;
    foreach (@problems) {
        if ($_->confirmed >= $now->clone->subtract(days => 7)) {
            push @{$problems{1}}, $_;
        } elsif ($_->confirmed >= $now->clone->subtract(days => 14)) {
            push @{$problems{2}}, $_;
        } else {
            push @{$problems{3}}, $_;
        }
    }
    $c->stash->{lists} = \%problems;

    if ( $c->get_param('export') ) {
        $self->export_as_csv($c, $problems_rs, $body);
    }
}

sub export_as_csv {
    my ($self, $c, $problems_rs, $body) = @_;
    require Text::CSV;
    my $problems = $problems_rs->search(
        {}, { prefetch => 'comments' });

    my $filename = do {
        my %where = (
            body     => $body->id,
            category => $c->stash->{category},
            state    => $c->stash->{q_state},
            ward     => $c->stash->{ward},
        );
        join '-',
            $c->req->uri->host,
            map {
                my $value = $where{$_};
                (defined $value and length $value) ? ($_, $value) : ()
            } sort keys %where };

    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    $csv->combine(
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
            'Nearest Postcode',
            'Report URL',
            );
    my @body = ($csv->string);

    my $fixed_states = FixMyStreet::DB::Result::Problem->fixed_states;
    my $closed_states = FixMyStreet::DB::Result::Problem->closed_states;

    while ( my $report = $problems->next ) {
        my $external_body;
        my $body_name = "";
        if ( $external_body = $report->body($c) ) {
            # seems to be a zurich specific thing
            $body_name = $external_body->name if ref $external_body;
        }
        my $hashref = $report->as_hashref($c);

        $hashref->{user_name_display} = $report->anonymous?
            '(anonymous)' : $report->user->name;

        for my $comment ($report->comments) {
            my $problem_state = $comment->problem_state or next;
            next if $problem_state eq 'confirmed';
            $hashref->{acknowledged_pp} //= $c->cobrand->prettify_dt( $comment->created );
            $hashref->{fixed_pp} //= $fixed_states->{ $problem_state } ?
                $c->cobrand->prettify_dt( $comment->created ): undef;
            if ($closed_states->{ $problem_state }) {
                $hashref->{closed_pp} = $c->cobrand->prettify_dt( $comment->created );
                last;
            }
        }

        $csv->combine(
            @{$hashref}{
                'id',
                'title',
                'detail',
                'user_name_display',
                'category',
                'created_pp',
                'confirmed_pp',
                'acknowledged_pp',
                'fixed_pp',
                'closed_pp',
                'state',
                'latitude', 'longitude',
                'postcode',
                },
            (join '', $c->cobrand->base_url_for_report($report), $report->url),
        );

        push @body, $csv->string;
    }
    $c->res->content_type('text/csv; charset=utf-8');
    $c->res->header('content-disposition' => "attachment; filename=${filename}.csv");
    $c->res->body( join "", @body );
}

sub updates_search : Private {
    my ( $self, $c, $time ) = @_;

    my $body = $c->stash->{body};

    my $params = {
        %{$c->stash->{where}},
        'me.confirmed' => { '>=', $time },
    };

    my $comments = $c->model('DB::Comment')->to_body($body)->search(
        $params,
        {
            group_by => [ 'problem_state' ],
            select   => [ 'problem_state', { count => 'me.id' } ],
            as       => [ qw/state state_count/ ],
            join     => 'problem'
        }
    );

    my %counts =
      map { ($_->state||'-') => $_->get_column('state_count') } $comments->all;
    %counts =
      map { $_ => $counts{$_} || 0 }
      ('confirmed', 'investigating', 'in progress', 'closed', 'fixed - council',
          'fixed - user', 'fixed', 'unconfirmed', 'hidden',
          'partial', 'action scheduled', 'planned');

      $counts{'action scheduled'} += $counts{planned} || 0;

    for my $vars (
        [ 'time_to_fix', 'fixed - council' ],
        [ 'time_to_mark', 'in progress', 'action scheduled', 'investigating', 'closed' ],
    ) {
        my $col = shift @$vars;
        my $substmt = "select min(id) from comment where me.problem_id=comment.problem_id and problem_state in ('"
            . join("','", @$vars) . "')";
        $comments = $c->model('DB::Comment')->to_body($body)->search(
            { %$params,
                problem_state => $vars,
                'me.id' => \"= ($substmt)",
            },
            {
                select   => [
                    { count => 'me.id' },
                    { avg => { extract => "epoch from me.confirmed-problem.confirmed" } },
                ],
                as       => [ qw/state_count time/ ],
                join     => 'problem'
            }
        )->first;
        $counts{$col} = int( ($comments->get_column('time')||0) / 60 / 60 / 24 + 0.5 );
    }

    $counts{fixed_user} = $c->model('DB::Comment')->to_body($body)->search(
        { %$params, mark_fixed => 1, problem_state => undef }, { join     => 'problem' }
    )->count;

    $params = {
        %{$c->stash->{prob_where}},
        'me.confirmed' => { '>=', $time },
    };
    $counts{total} = $c->cobrand->problems->to_body($body)->search( $params )->count;

    $params = {
        %{$c->stash->{prob_where}},
        'me.confirmed' => { '>=', $time },
        state => 'confirmed',
        '(select min(id) from comment where me.id=problem_id and problem_state is not null)' => undef,
    };
    $counts{not_marked} = $c->cobrand->problems->to_body($body)->search( $params )->count;

    return \%counts;
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;

