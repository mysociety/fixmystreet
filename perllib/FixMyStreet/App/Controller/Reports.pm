package FixMyStreet::App::Controller::Reports;
use Moose;
use namespace::autoclean;

use File::Slurp;
use JSON::MaybeXS;
use List::MoreUtils qw(any);
use POSIX qw(strcoll);
use RABX;
use mySociety::MaPit;

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

    # Zurich goes straight to map page, with all reports
    if ( $c->cobrand->moniker eq 'zurich' ) {
        $c->forward( 'stash_report_filter_status' );
        $c->forward( 'load_and_group_problems' );
        my $pins = $c->stash->{pins};
        $c->stash->{page} = 'reports';
        FixMyStreet::Map::display_map(
            $c,
            latitude  => @$pins ? $pins->[0]{latitude} : 0,
            longitude => @$pins ? $pins->[0]{longitude} : 0,
            area      => 274456,
            pins      => $pins,
            any_zoom  => 1,
        );
        return 1;
    }

    if ( my $body = $c->cobrand->all_reports_single_body ) {
        $c->stash->{body} = $body;
        $c->detach( 'redirect_body' );
    }

    # Fetch all bodies
    my @bodies = $c->model('DB::Body')->search({}, {
        '+select' => [ { count => 'area_id' } ],
        '+as' => [ 'area_count' ],
        join => 'body_areas',
        distinct => 1,
    })->all;
    @bodies = sort { strcoll($a->name, $b->name) } @bodies;
    $c->stash->{bodies} = \@bodies;
    $c->stash->{any_empty_bodies} = any { $_->get_column('area_count') == 0 } @bodies;

    eval {
        my $data = File::Slurp::read_file(
            FixMyStreet->path_to( '../data/all-reports.json' )->stringify
        );
        my $j = decode_json($data);
        $c->stash->{fixed} = $j->{fixed};
        $c->stash->{open} = $j->{open};
    };
    if ($@) {
        $c->stash->{message} = _("There was a problem showing the All Reports page. Please try again later.");
        if ($c->config->{STAGING_SITE}) {
            $c->stash->{message} .= '</p><p>Perhaps the bin/update-all-reports script needs running. Use: bin/update-all-reports</p><p>'
                . sprintf(_('The error was: %s'), $@);
        }
        $c->stash->{template} = 'errors/generic.html';
        return;
    }

    # Down here so that error pages aren't cached.
    $c->response->header('Cache-Control' => 'max-age=3600');
}

=head2 index

Show the summary page for a particular body.

=cut

sub body : Path : Args(1) {
    my ( $self, $c, $body ) = @_;
    $c->detach( 'ward', [ $body ] );
}

=head2 index

Show the summary page for a particular ward.

=cut

sub ward : Path : Args(2) {
    my ( $self, $c, $body, $ward ) = @_;

    $c->forward( 'body_check', [ $body ] );
    $c->forward( 'ward_check', [ $ward ] )
        if $ward;
    $c->forward( 'check_canonical_url', [ $body ] );
    $c->forward( 'stash_report_filter_status' );
    $c->forward( 'load_and_group_problems' );

    my $body_short = $c->cobrand->short_name( $c->stash->{body} );
    $c->stash->{rss_url} = '/rss/reports/' . $body_short;
    $c->stash->{rss_url} .= '/' . $c->cobrand->short_name( $c->stash->{ward} )
        if $c->stash->{ward};

    $c->stash->{body_url} = '/reports/' . $body_short;

    $c->stash->{stats} = $c->cobrand->get_report_stats();

    my @categories = $c->stash->{body}->contacts->not_deleted->search( undef, {
        columns => [ 'category' ],
        distinct => 1,
        order_by => [ 'category' ],
    } )->all;
    @categories = map { $_->category } @categories;
    $c->stash->{filter_categories} = \@categories;
    $c->stash->{filter_category} = $c->get_param('filter_category');

    my $pins = $c->stash->{pins};

    $c->stash->{page} = 'reports'; # So the map knows to make clickable pins
    my %map_params = (
        latitude  => @$pins ? $pins->[0]{latitude} : 0,
        longitude => @$pins ? $pins->[0]{longitude} : 0,
        area      => $c->stash->{ward} ? $c->stash->{ward}->{id} : [ keys %{$c->stash->{body}->areas} ],
        any_zoom  => 1,
    );
    FixMyStreet::Map::display_map(
        $c, %map_params, pins => $pins,
    );

    $c->cobrand->tweak_all_reports_map( $c );

    # List of wards
    if ( !$c->stash->{ward} && $c->stash->{body}->id && $c->stash->{body}->body_areas->first ) {
        my $children = mySociety::MaPit::call('area/children', [ $c->stash->{body}->body_areas->first->area_id ],
            type => $c->cobrand->area_types_children,
        );
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
    my $areas = mySociety::MaPit::call( 'areas', $area,
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

    # We must now have a string to check
    my @bodies = $c->model('DB::Body')->search( { name => { -like => "$q_body%" } } )->all;

    if (@bodies == 1) {
        $c->stash->{body} = $bodies[0];
        return;
    } else {
        foreach (@bodies) {
            if (lc($_->name) eq lc($q_body) || $_->name =~ /^\Q$q_body\E (Borough|City|District|County) Council$/i) {
                $c->stash->{body} = $_;
                return;
            }
        }
    }

    # No result, bad body name.
    $c->detach( 'redirect_index' );
}

=head2 ward_check

This action checks the ward name from a URI exists and is part of the right
parent, already found with body_check. It either stores the ward Area if
okay, or redirects to the body page if bad.

=cut

sub ward_check : Private {
    my ( $self, $c, $ward ) = @_;

    $ward =~ s/\+/ /g;
    $ward =~ s/\.html//;
    $ward =~ s{_}{/}g;

    # Could be from RSS area, or body...
    my $parent_id;
    if ( $c->stash->{body} ) {
        $parent_id = $c->stash->{body}->body_areas->first;
        $c->detach( 'redirect_body' ) unless $parent_id;
        $parent_id = $parent_id->area_id;
    } else {
        $parent_id = $c->stash->{area}->{id};
    }

    my $qw = mySociety::MaPit::call('areas', $ward,
        type => $c->cobrand->area_types_children,
    );
    foreach my $area (sort { $a->{name} cmp $b->{name} } values %$qw) {
        if ($area->{parent_area} == $parent_id) {
            $c->stash->{ward} = $area;
            return;
        }
    }
    # Given a false ward name
    $c->stash->{body} = $c->stash->{area}
        unless $c->stash->{body};
    $c->detach( 'redirect_body' );
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

sub load_and_group_problems : Private {
    my ( $self, $c ) = @_;

    my $page = $c->get_param('p') || 1;
    # NB: If 't' is specified, it will override 'status'.
    my $type = $c->get_param('t') || 'all';
    my $category = $c->get_param('c') || $c->get_param('filter_category') || '';

    my $states = $c->stash->{filter_problem_states};
    my $where = {
        non_public => 0,
        state      => [ keys %$states ]
    };

    my $not_open = [ FixMyStreet::DB::Result::Problem::fixed_states(), FixMyStreet::DB::Result::Problem::closed_states() ];
    if ( $type eq 'new' ) {
        $where->{confirmed} = { '>', \"current_timestamp - INTERVAL '4 week'" };
        $where->{state} = { 'IN', [ FixMyStreet::DB::Result::Problem::open_states() ] };
    } elsif ( $type eq 'older' ) {
        $where->{confirmed} = { '<', \"current_timestamp - INTERVAL '4 week'" };
        $where->{lastupdate} = { '>', \"current_timestamp - INTERVAL '8 week'" };
        $where->{state} = { 'IN', [ FixMyStreet::DB::Result::Problem::open_states() ] };
    } elsif ( $type eq 'unknown' ) {
        $where->{lastupdate} = { '<', \"current_timestamp - INTERVAL '8 week'" };
        $where->{state} = { 'IN',  [ FixMyStreet::DB::Result::Problem::open_states() ] };
    } elsif ( $type eq 'fixed' ) {
        $where->{lastupdate} = { '>', \"current_timestamp - INTERVAL '8 week'" };
        $where->{state} = $not_open;
    } elsif ( $type eq 'older_fixed' ) {
        $where->{lastupdate} = { '<', \"current_timestamp - INTERVAL '8 week'" };
        $where->{state} = $not_open;
    }

    if ($category) {
        $where->{category} = $category;
    }

    my $problems = $c->cobrand->problems;

    if ($c->stash->{ward}) {
        $where->{areas} = { 'like', '%,' . $c->stash->{ward}->{id} . ',%' };
        $problems = $problems->to_body($c->stash->{body});
    } elsif ($c->stash->{body}) {
        $problems = $problems->to_body($c->stash->{body});
    }

    $problems = $problems->search(
        $where,
        {
            order_by => $c->cobrand->reports_ordering,
            rows => $c->cobrand->reports_per_page,
        }
    )->page( $page );
    $c->stash->{pager} = $problems->pager;

    my ( %problems, @pins );
    while ( my $problem = $problems->next ) {
        $c->log->debug( $problem->cobrand . ', cobrand is ' . $c->cobrand->moniker );
        if ( !$c->stash->{body} ) {
            add_row( $c, $problem, 0, \%problems, \@pins );
            next;
        }
        if ( !$problem->bodies_str ) {
            # Problem was not sent to any body, add to all possible areas XXX
            my $a = $problem->areas; # Store, as otherwise is looked up every iteration.
            while ($a =~ /,(\d+)(?=,)/g) {
                add_row( $c, $problem, $1, \%problems, \@pins );
            }
        } else {
            # Add to bodies it was sent to
            my $bodies = $problem->bodies_str_ids;
            foreach ( @$bodies ) {
                next if $_ != $c->stash->{body}->id;
                add_row( $c, $problem, $_, \%problems, \@pins );
            }
        }
    }

    $c->stash(
        problems      => \%problems,
        pins          => \@pins,
    );

    return 1;
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
    $url   .= '/' . $c->cobrand->short_name( $c->stash->{ward} )
        if $c->stash->{ward};
    $c->res->redirect( $c->uri_for($url, $c->req->params ) );
}

sub stash_report_filter_status : Private {
    my ( $self, $c ) = @_;

    my $status = $c->get_param('status') || $c->cobrand->on_map_default_status;
    if ( $status eq 'all' ) {
        $c->stash->{filter_status} = 'all';
        $c->stash->{filter_problem_states} = FixMyStreet::DB::Result::Problem->visible_states();
    } elsif ( $status eq 'open' ) {
        $c->stash->{filter_status} = 'open';
        $c->stash->{filter_problem_states} = FixMyStreet::DB::Result::Problem->open_states();
    } elsif ( $status eq 'closed' ) {
        $c->stash->{filter_status} = 'closed';
        $c->stash->{filter_problem_states} = FixMyStreet::DB::Result::Problem->closed_states();
    } elsif ( $status eq 'fixed' ) {
        $c->stash->{filter_status} = 'fixed';
        $c->stash->{filter_problem_states} = FixMyStreet::DB::Result::Problem->fixed_states();
    } else {
        $c->stash->{filter_status} = $c->cobrand->on_map_default_status;
    }

    return 1;
}

sub add_row {
    my ( $c, $problem, $body, $problems, $pins ) = @_;
    push @{$problems->{$body}}, $problem;
    push @$pins, {
        latitude  => $problem->latitude,
        longitude => $problem->longitude,
        colour    => $c->cobrand->pin_colour( $problem, 'reports' ),
        id        => $problem->id,
        title     => $problem->title_safe,
    };
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;

