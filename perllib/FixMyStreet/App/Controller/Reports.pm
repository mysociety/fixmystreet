package FixMyStreet::App::Controller::Reports;
use Moose;
use namespace::autoclean;

use JSON::MaybeXS;
use List::MoreUtils qw(any);
use Path::Tiny;
use RABX;
use FixMyStreet::MapIt;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Reports - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

Show the summary page of all reports.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->cobrand->call_hook('report_page_data') ) {
        return 1;
    }

    if ( my $body = $c->cobrand->all_reports_single_body ) {
        $c->stash->{body} = $body;
        $c->detach( 'redirect_body' );
    }

    $c->forward('display_body_stats');

    my $dashboard = $c->forward('load_dashboard_data');

    my $table = !$c->stash->{body} && eval {
        my $data = path(FixMyStreet->path_to('../data/all-reports.json'))->slurp_utf8;
        $c->stash(decode_json($data));
        return 1;
    };
    if (!$dashboard && !$table) {
        $c->detach('/page_error_404_not_found') if $c->stash->{body};

        my $message = _("There was a problem showing the All Reports page. Please try again later.");
        if ($c->config->{STAGING_SITE}) {
            $message .= '</p><p>Perhaps the bin/update-all-reports script needs running. Use: bin/update-all-reports</p><p>'
                . sprintf(_('The error was: %s'), $@);
        }
        $c->detach('/page_error_500_internal_error', [ $message ]);
    }

    if ($c->stash->{body}) {
        my $children = $c->stash->{body}->first_area_children;
        unless ($children->{error}) {
            $c->stash->{children} = $children;
        }
    } else {
        my @bodies = $c->model('DB::Body')->search(undef, {
            columns => [ "id", "name" ],
        })->active->translated->with_area_count->all_sorted;
        @bodies = @{$c->cobrand->call_hook('reports_hook_restrict_bodies_list', \@bodies) || \@bodies };
        $c->stash->{bodies} = \@bodies;
    }

    # Down here so that error pages aren't cached.
    my $max_age = FixMyStreet->config('CACHE_TIMEOUT') // 3600;
    $c->response->header('Cache-Control' => 'max-age=' . $max_age);
}

=head2 display_body_stats

Show the stats for a body if body param is set.

=cut

sub display_body_stats : Private {
    my ( $self, $c ) = @_;
    if (my $body = $c->get_param('body')) {
        $body = $c->model('DB::Body')->find( { id => $body } );
        if ($body) {
            $body = $c->cobrand->short_name($body);
            $c->res->redirect("/reports/$body");
            $c->detach;
        }
    }
}

=head2 body

Show the summary page for a particular body.

=cut

sub body : Path : Args(1) {
    my ( $self, $c, $body ) = @_;
    $c->detach( 'ward', [ $body ] );
}

=head2 ward

Show the summary page for a particular ward.

=cut

sub ward : Path : Args(2) {
    my ( $self, $c, $body, $ward ) = @_;

    $c->forward('/auth/get_csrf_token');

    my @wards = $c->get_param('wards') ? $c->get_param_list('wards', 1) : split /\|/, $ward || "";
    $c->forward( 'body_check', [ $body ] );

    # If viewing multiple wards, rewrite the url from
    # /reports/Borsetshire?ward=North&ward=East
    # to
    # /reports/Borsetshire/North|East
    my @ward_params = $c->get_param_list('ward');
    if ( @ward_params ) {
        $c->stash->{wards} = [ map { { name => $_ } } (@wards, @ward_params) ];
        delete $c->req->params->{ward};
        $c->detach("redirect_body");
    }

    my $body_short = $c->cobrand->short_name( $c->stash->{body} );
    $c->stash->{body_url} = '/reports/' . $body_short;

    if ($ward && $ward eq 'summary') {
        if (my $actual_ward = $c->get_param('ward')) {
            $ward = $c->cobrand->short_name({ name => $actual_ward });
            $c->res->redirect($ward);
            $c->detach;
        }
        $c->cobrand->call_hook('council_dashboard_hook');
        $c->go('index');
    }

    $c->stash->{page} = 'reports'; # So the map knows to make clickable pins

    $c->forward( 'ward_check', [ @wards ] )
        if @wards;
    $c->forward( 'check_canonical_url', [ $body ] );
    $c->forward( 'stash_report_filter_status' );
    $c->forward( 'load_and_group_problems' );

    if ($c->get_param('ajax')) {
        my $ajax_template = $c->stash->{ajax_template} || 'reports/_problem-list.html';
        $c->detach('ajax', [ $ajax_template ]);
    }

    $c->stash->{rss_url} = '/rss/reports/' . $body_short;
    $c->stash->{rss_url} .= '/' . $c->cobrand->short_name( $c->stash->{ward} )
        if $c->stash->{ward};

    $c->stash->{stats} = $c->cobrand->get_report_stats();

    my @categories = $c->stash->{body}->contacts->not_deleted->search( undef, {
        columns => [ 'id', 'category', 'extra' ],
        distinct => 1,
        order_by => [ 'category' ],
    } )->all;
    $c->stash->{filter_categories} = \@categories;
    $c->stash->{filter_category} = { map { $_ => 1 } $c->get_param_list('filter_category', 1) };

    my $pins = $c->stash->{pins} || [];

    my %map_params = (
        latitude  => @$pins ? $pins->[0]{latitude} : 0,
        longitude => @$pins ? $pins->[0]{longitude} : 0,
        area      => [ $c->stash->{wards} ? map { $_->{id} } @{$c->stash->{wards}} : keys %{$c->stash->{body}->areas} ],
        any_zoom  => 1,
    );
    FixMyStreet::Map::display_map(
        $c, %map_params, pins => $pins,
    );

    $c->cobrand->tweak_all_reports_map( $c );

    # List of wards
    if ( !$c->stash->{wards} && $c->stash->{body}->id && $c->stash->{body}->body_areas->first ) {
        my $children = $c->stash->{body}->first_area_children;
        unless ($children->{error}) {
            foreach (values %$children) {
                $_->{url} = $c->uri_for( $c->stash->{body_url}
                    . '/' . $c->cobrand->short_name( $_ )
                );
            }
            $c->stash->{children} = $children;
        }
    }
}

sub rss_area : Path('/rss/area') : Args(1) {
    my ( $self, $c, $area ) = @_;
    $c->detach( 'rss_area_ward', [ $area ] );
}

sub rss_area_ward : Path('/rss/area') : Args(2) {
    my ( $self, $c, $area, $ward ) = @_;

    $c->stash->{rss} = 1;

    # area_check

    $area =~ s/\+/ /g;
    $area =~ s/\.html//;

    # XXX Currently body/area overlaps here are a bit muddy.
    # We're checking an area here, but this function is currently doing that.
    return if $c->cobrand->reports_body_check( $c, $area );

    # We must now have a string to check on mapit
    my $areas = FixMyStreet::MapIt::call( 'areas', $area,
        type => $c->cobrand->area_types,
    );

    if (keys %$areas == 1) {
        ($c->stash->{area}) = values %$areas;
    } else {
        foreach (keys %$areas) {
            if (lc($areas->{$_}->{name}) eq lc($area) || $areas->{$_}->{name} =~ /^\Q$area\E (Borough|City|District|County) Council$/i) {
                $c->stash->{area} = $areas->{$_};
            }
        }
    }

    $c->detach( 'redirect_index' ) unless $c->stash->{area};

    $c->forward( 'ward_check', [ $ward ] ) if $ward;

    my $url = $c->cobrand->short_name( $c->stash->{area} );
    $url .= '/' . $c->cobrand->short_name( $c->stash->{ward} ) if $c->stash->{ward};
    $c->stash->{qs} = "/$url";

    if ($c->cobrand->moniker eq 'fixmystreet' && $c->stash->{area}{type} ne 'DIS' && $c->stash->{area}{type} ne 'CTY') {
        # UK-specific types - two possibilites are the same for one-tier councils, so redirect one to the other
        # With bodies, this should presumably redirect if only one body covers
        # the area, and then it will need that body's name (rather than
        # assuming as now it is the same as the area)
        $c->stash->{body} = $c->stash->{area};
        $c->detach( 'redirect_body' );
    }

    $c->stash->{type} = 'area_problems';
    if ( $c->stash->{ward} ) {
        # All problems within a particular ward
        $c->stash->{title_params} = { NAME => $c->stash->{ward}{name} };
        $c->stash->{db_params}    = [ $c->stash->{ward}->{id} ];
    } else {
        # Problems within a particular area
        $c->stash->{title_params} = { NAME => $c->stash->{area}->{name} };
        $c->stash->{db_params}    = [ $c->stash->{area}->{id} ];
    }

    # Send on to the RSS generation
    $c->forward( '/rss/output' );

}

sub rss_body : Path('/rss/reports') : Args(1) {
    my ( $self, $c, $body ) = @_;
    $c->detach( 'rss_ward', [ $body ] );
}

sub rss_ward : Path('/rss/reports') : Args(2) {
    my ( $self, $c, $body, $ward ) = @_;

    $c->stash->{rss} = 1;

    $c->forward( 'body_check', [ $body ] );
    $c->forward( 'ward_check', [ $ward ] ) if $ward;

    my $url =       $c->cobrand->short_name( $c->stash->{body} );
    $url   .= '/' . $c->cobrand->short_name( $c->stash->{ward} ) if $c->stash->{ward};
    $c->stash->{qs} = "/$url";

    if ($c->stash->{ward}) {
        # Problems sent to a council, restricted to a ward
        $c->stash->{type} = 'ward_problems';
        $c->stash->{title_params} = { COUNCIL => $c->stash->{body}->name, WARD => $c->stash->{ward}{name} };
        $c->stash->{db_params} = [ $c->stash->{body}->id, $c->stash->{ward}->{id} ];
    } else {
        # Problems sent to a council
        $c->stash->{type} = 'council_problems';
        $c->stash->{title_params} = { COUNCIL => $c->stash->{body}->name };
        $c->stash->{db_params} = [ $c->stash->{body}->id ];
    }

    # Send on to the RSS generation
    $c->forward( '/rss/output' );
}

=head2 body_check

This action checks the body name (or code) given in a URI exists, is valid and
so on. If it is, it stores the body in the stash, otherwise it redirects to the
all reports page.

=cut

sub body_check : Private {
    my ( $self, $c, $q_body ) = @_;

    $q_body =~ s/\+/ /g;
    $q_body =~ s/\.html//;

    # Check cobrand specific incantations - e.g. ONS codes for UK,
    # Oslo/ kommunes sharing a name in Norway
    return if $c->cobrand->reports_body_check( $c, $q_body );

    my $body = $c->forward('body_find', [ $q_body ]);
    if ($body) {
        $c->stash->{body} = $body;
        return;
    }

    # No result, bad body name.
    $c->detach( 'redirect_index' );
}

=head2

Given a string, try and find a body starting with/matching that string.
Returns the matching body object if found.

=cut

sub body_find : Private {
    my ($self, $c, $q_body) = @_;

    # We must now have a string to check
    my @bodies = $c->model('DB::Body')->search( { name => { -like => "$q_body%" } } )->all;

    if (@bodies == 1) {
        return $bodies[0];
    } else {
        foreach (@bodies) {
            if (lc($_->name) eq lc($q_body) || $_->name =~ /^\Q$q_body\E (Borough|City|District|County) Council$/i) {
                return $_;
            }
        }
    }

    my @translations = $c->model('DB::Translation')->search( {
        tbl => 'body',
        col => 'name',
        msgstr => $q_body
    } )->all;

    if (@translations == 1) {
        if ( my $body = $c->model('DB::Body')->find( { id => $translations[0]->object_id } ) ) {
            return $body;
        }
    }
}

=head2 ward_check

This action checks the ward names from a URI exists and are part of the right
parent, already found with body_check. It either stores the ward Area if
okay, or redirects to the body page if bad.

=cut

sub ward_check : Private {
    my ( $self, $c, @wards ) = @_;

    foreach (@wards) {
        s/\+/ /g;
        s/\.html//;
        s{_}{/}g;
    }

    # Could be from RSS area, or body...
    my $parent_id;
    if ( $c->stash->{body} ) {
        $parent_id = $c->stash->{body}->body_areas->first;
        $c->detach( 'redirect_body' ) unless $parent_id;
        $parent_id = $parent_id->area_id;
    } else {
        $parent_id = $c->stash->{area}->{id};
    }

    my $qw = FixMyStreet::MapIt::call('area/children', [ $parent_id ],
        type => $c->cobrand->area_types_children,
    );
    my %names = map { $c->cobrand->short_name({ name => $_ }) => 1 } @wards;
    my @areas;
    foreach my $area (sort { $a->{name} cmp $b->{name} } values %$qw) {
        my $name = $c->cobrand->short_name($area);
        push @areas, $area if $names{$name};
    }
    if (@areas) {
        $c->stash->{ward} = $areas[0] if @areas == 1;
        $c->stash->{wards} = \@areas;
        return;
    }

    # Given a false ward name
    $c->stash->{body} = $c->stash->{area}
        unless $c->stash->{body};
    $c->detach( 'redirect_body' );
}

=head2 summary

This is the summary page used on fixmystreet.com

=cut

sub summary : Private {
    my ($self, $c) = @_;
    my $dashboard = $c->forward('load_dashboard_data');

    $c->log->info($c->user->email . ' viewed ' . $c->req->uri->path_query) if $c->user_exists;

    eval {
        my $data = path(FixMyStreet->path_to('../data/all-reports-dashboard.json'))->slurp_utf8;
        $data = decode_json($data);
        $c->stash(
            top_five_bodies => $data->{top_five_bodies},
            average => $data->{average},
        );
    };

    my $dtf = $c->model('DB')->storage->datetime_parser;
    my $period = $c->stash->{period} = $c->get_param('period') || '';
    my $start_date;
    if ($period eq 'ever') {
        $start_date = DateTime->new(year => 2007);
    } elsif ($period eq 'year') {
        $start_date = DateTime->now->subtract(years => 1);
    } elsif ($period eq '3months') {
        $start_date = DateTime->now->subtract(months => 3);
    } elsif ($period eq 'week') {
        $start_date = DateTime->now->subtract(weeks => 1);
    } else {
        $c->stash->{period} = 'month';
        $start_date = DateTime->now->subtract(months => 1);
    }

    # required to stop errors in generate_grouped_data
    $c->stash->{q_state} = '';
    $c->stash->{ward} = [ $c->get_param('area') || () ];
    $c->stash->{start_date} = $dtf->format_date($start_date);
    $c->stash->{end_date} = $c->get_param('end_date');

    $c->stash->{group_by_default} = 'category';

    my $children = $c->stash->{body}->first_area_children;
    $c->stash->{children} = $children;

    $c->forward('/admin/fetch_contacts');
    $c->stash->{contacts} = [ $c->stash->{contacts}->all ];

    $c->forward('/dashboard/construct_rs_filter', []);

    if ( $c->get_param('csv') ) {
        $c->detach('export_summary_csv');
    }

    $c->forward('/dashboard/generate_grouped_data');
    $c->forward('/dashboard/generate_body_response_time');

    $c->stash->{template} = 'reports/summary.html';
}

sub export_summary_csv : Private {
    my ( $self, $c ) = @_;

    $c->stash->{csv} = {
        objects => $c->stash->{objects_rs}->search_rs({}, {
            rows => 100,
            order_by => { '-desc' => 'me.confirmed' },
        }),
        headers => [
            'Report ID',
            'Title',
            'Category',
            'Created',
            'Confirmed',
            'Status',
            'Latitude', 'Longitude',
            'Query',
            'Report URL',
        ],
        columns => [
            'id',
            'title',
            'category',
            'created',
            'confirmed',
            'state',
            'latitude', 'longitude',
            'postcode',
            'url',
        ],
        filename => 'fixmystreet-data',
    };
    $c->forward('/dashboard/generate_csv');
}

=head2 check_canonical_url

Given an already found (case-insensitively) body, check what URL
we are at and redirect accordingly if different.

=cut

sub check_canonical_url : Private {
    my ( $self, $c, $q_body ) = @_;

    my $body_short = $c->cobrand->short_name( $c->stash->{body} );
    my $url_short = URI::Escape::uri_escape_utf8($q_body);
    $url_short =~ s/%2B/+/g;
    $c->detach( 'redirect_body' ) unless $body_short eq $url_short;
}

sub load_dashboard_data : Private {
    my ($self, $c) = @_;
    my $dashboard = eval {
        my $data = FixMyStreet->config('TEST_DASHBOARD_DATA');
        # uncoverable branch true
        unless ($data) {
            my $fn = '../data/all-reports-dashboard';
            if ($c->stash->{body}) {
                $fn .= '-' . $c->stash->{body}->id;
            }
            $data = decode_json(path(FixMyStreet->path_to($fn . '.json'))->slurp_utf8);
        }
        $c->stash($data);
        return 1;
    };

    return $dashboard;
}

sub load_and_group_problems : Private {
    my ( $self, $c ) = @_;

    $c->forward('stash_report_sort', [ $c->cobrand->reports_ordering ]);

    my $page = $c->get_param('p') || 1;
    my $category = [ $c->get_param_list('filter_category', 1) ];

    my $states = $c->stash->{filter_problem_states};
    my $where = {
        'me.state' => [ keys %$states ]
    };

    $c->forward('check_non_public_reports_permission', [ $where ] );

    my $body = $c->stash->{body}; # Might be undef

    my $filter = {
        order_by => $c->stash->{sort_order},
        rows => $c->cobrand->reports_per_page,
    };
    if ($c->user_exists && $body) {
        my $prefetch = [];
        if ($c->user->has_permission_to('planned_reports', $body->id)) {
            push @$prefetch, 'user_planned_reports';
        }
        if ($c->user->has_permission_to('report_edit_priority', $body->id) || $c->user->has_permission_to('report_inspect', $body->id)) {
            push @$prefetch, 'response_priority';
        }
        $prefetch = $prefetch->[0] if @$prefetch == 1;
        $filter->{prefetch} = $prefetch;
    }

    if (defined $c->stash->{filter_status}{shortlisted}) {
        $where->{'me.id'} = { '=', \"user_planned_reports.report_id"};
        $where->{'user_planned_reports.removed'} = undef;
        $filter->{join} = 'user_planned_reports';
    } elsif (defined $c->stash->{filter_status}{unshortlisted}) {
        my $shortlisted_ids = $c->cobrand->problems->search({
            'me.id' => { '=', \"user_planned_reports.report_id"},
            'user_planned_reports.removed' => undef,
        }, {
           join => 'user_planned_reports',
           columns => ['me.id'],
        })->as_query;
        $where->{'me.id'} = { -not_in => $shortlisted_ids };
    }

    if (@$category) {
        $where->{category} = $category;
    }

    my $problems = $c->cobrand->problems;

    if ($c->stash->{wards}) {
        $where->{areas} = [
            map { { 'like', '%,' . $_->{id} . ',%' } } @{$c->stash->{wards}}
        ];
        $problems = $problems->to_body($body);
    } elsif ($body) {
        $problems = $problems->to_body($body);
    }

    if (my $bbox = $c->get_param('bbox')) {
        my ($min_lon, $min_lat, $max_lon, $max_lat) = split /,/, $bbox;
        $where->{latitude} = { '>=', $min_lat, '<', $max_lat };
        $where->{longitude} = { '>=', $min_lon, '<', $max_lon };
    }

    my $cobrand_problems = $c->cobrand->call_hook('munge_load_and_group_problems', $where, $filter);

    # JS will request the same (or more) data client side
    return if $c->get_param('js');

    if ($cobrand_problems) {
        $problems = $cobrand_problems;
    } else {
        $problems = $problems->search(
            $where,
            $filter
        )->include_comment_counts->page( $page );

        $c->stash->{pager} = $problems->pager;
    }

    my ( %problems, @pins );
    while ( my $problem = $problems->next ) {
        if ( !$body ) {
            add_row( $c, $problem, 0, \%problems, \@pins );
            next;
        }
        # Add to bodies it was sent to
        my $bodies = $problem->bodies_str_ids;
        foreach ( @$bodies ) {
            next if $_ != $body->id;
            add_row( $c, $problem, $_, \%problems, \@pins );
        }
    }

    $c->stash(
        problems      => \%problems,
        pins          => \@pins,
    );

    return 1;
}


sub check_non_public_reports_permission : Private {
    my ($self, $c, $where) = @_;

    if ( $c->user_exists ) {
        my $user_has_permission;

        if ( $c->user->is_super_user ) {
            $user_has_permission = 1;
        } else {
            my $body = $c->stash->{body};

            $user_has_permission = $body && (
                $c->user->has_permission_to('report_inspect', $body->id) ||
                $c->user->has_permission_to('report_mark_private', $body->id)
            );
        }

        if ( $user_has_permission ) {
            $where->{non_public} = 1 if $c->stash->{only_non_public};
        } else {
            $where->{non_public} = 0;
        }
    } else {
        $where->{non_public} = 0;
    }
}

sub redirect_index : Private {
    my ( $self, $c ) = @_;
    my $url = '/reports';
    $c->res->redirect( $c->uri_for($url) );
}

sub redirect_body : Private {
    my ( $self, $c ) = @_;
    my $url = '';
    $url   .= "/rss" if $c->stash->{rss};
    $url   .= '/reports';
    $url   .= '/' . $c->cobrand->short_name( $c->stash->{body} );
    $url   .= '/' . join('|', map { $c->cobrand->short_name($_) } @{$c->stash->{wards}})
        if $c->stash->{wards};
    $c->res->redirect( $c->uri_for($url, $c->req->params ) );
}

sub stash_report_filter_status : Private {
    my ( $self, $c ) = @_;

    my @status = $c->get_param_list('status', 1);
    @status = ($c->stash->{page} eq 'my' ? 'all' : $c->cobrand->on_map_default_status) unless @status;
    my %status = map { $_ => 1 } @status;

    my %filter_problem_states;
    my %filter_status;

    if ($status{open}) {
        my $s = FixMyStreet::DB::Result::Problem->open_states();
        %filter_problem_states = (%filter_problem_states, %$s);
        $filter_status{open} = 1;
        $filter_status{$_} = 1 for keys %$s;
    }
    if ($status{closed}) {
        my $s = FixMyStreet::DB::Result::Problem->closed_states();
        %filter_problem_states = (%filter_problem_states, %$s);
        $filter_status{closed} = 1;
        $filter_status{$_} = 1 for keys %$s;
    }
    if ($status{fixed}) {
        my $s = FixMyStreet::DB::Result::Problem->fixed_states();
        %filter_problem_states = (%filter_problem_states, %$s);
        $filter_status{fixed} = 1;
        $filter_status{$_} = 1 for keys %$s;
    }

    if ($status{all}) {
        my $s = FixMyStreet::DB::Result::Problem->visible_states();
        # %filter_status = ();
        %filter_problem_states = %$s;
    }

    if ($status{shortlisted}) {
        $filter_status{shortlisted} = 1;
    }

    if ($status{unshortlisted}) {
        $filter_status{unshortlisted} = 1;
    }

    my $body_user = $c->user_exists && $c->stash->{body} && $c->user->belongs_to_body($c->stash->{body}->id);
    my $staff_user = $c->user_exists && ($c->user->is_superuser || $body_user);
    if ($staff_user || $c->cobrand->call_hook('filter_show_all_states')) {
        $c->stash->{filter_states} = $c->cobrand->state_groups_inspect;
        foreach my $state (FixMyStreet::DB::Result::Problem->visible_states()) {
            if ($status{$state}) {
                $filter_problem_states{$state} = 1;
                $filter_status{$state} = 1;
            }
        }
    }

    if ($status{non_public}) {
        $c->stash->{only_non_public} = 1;
    }

    if (keys %filter_problem_states == 0) {
      my $s = FixMyStreet::DB::Result::Problem->open_states();
      %filter_problem_states = (%filter_problem_states, %$s);
    }

    $c->stash->{filter_problem_states} = \%filter_problem_states;
    $c->stash->{filter_status} = \%filter_status;
    return 1;
}

sub stash_report_sort : Private {
    my ( $self, $c, $default ) = @_;

    my %types = (
        updated => 'lastupdate',
        created => 'confirmed',
        comments => 'comment_count',
    );
    $types{created} = 'created' if $c->cobrand->moniker eq 'zurich';

    my $sort = $c->get_param('sort') || $default;
    $sort = $default unless $sort =~ /^((updated|created)-(desc|asc)|comments-desc|shortlist)$/;
    $c->stash->{sort_key} = $sort;

    # Going to do this sorting code-side
    $sort = 'created-desc' if $sort eq 'shortlist';

    $sort =~ /^(updated|created|comments)-(desc|asc)$/;
    my $order_by = $types{$1} || $1;
    # field to use for report age cutoff
    $c->stash->{report_age_field} = $order_by eq 'comment_count' ? 'lastupdate' : $order_by;
    my $dir = $2;
    $order_by = { -desc => $order_by } if $dir eq 'desc';

    $c->stash->{sort_order} = $order_by;

    return 1;
}

sub add_row {
    my ( $c, $problem, $body, $problems, $pins ) = @_;
    push @{$problems->{$body}}, $problem;
    push @$pins, $problem->pin_data($c, 'reports');
}

sub ajax : Private {
    my ($self, $c, $template) = @_;

    $c->res->content_type('application/json; charset=utf-8');
    $c->res->header( 'Cache_Control' => 'max-age=0' );

    my @pins = map {
        my $p = $_;
        # lat, lon, 'colour', ID, title, type/size, draggable
        [ $p->{latitude}, $p->{longitude}, $p->{colour}, $p->{id}, $p->{title}, '', JSON->false ]
    } @{$c->stash->{pins}};

    my $list_html = $c->render_fragment($template);

    my $pagination = $c->render_fragment('pagination.html', {
        pager => $c->stash->{problems_pager} || $c->stash->{pager},
        param => 'p',
    });

    my $json = {
        pins => \@pins,
        pagination => $pagination,
    };
    $json->{reports_list} = $list_html if $list_html;
    my $body = encode_json($json);
    $c->res->body($body);
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;
