package FixMyStreet::App::Controller::Reports;
use Moose;
use namespace::autoclean;

use File::Slurp;
use List::MoreUtils qw(zip);
use POSIX qw(strcoll);
use mySociety::MaPit;
use mySociety::VotingArea;

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

    $c->response->header('Cache-Control' => 'max-age=3600');

    # Fetch all areas of the types we're interested in
    my @area_types = $c->cobrand->area_types;
    my $areas_info = mySociety::MaPit::call('areas', \@area_types,
        min_generation => $c->cobrand->area_min_generation
    );

    # For each area, add its link and perhaps alter its name if we need to for
    # places with the same name.
    foreach (values %$areas_info) {
        $_->{url} = $c->uri_for( '/reports/' . $c->cobrand->short_name( $_, $areas_info ) );
        if ($_->{parent_area} && $_->{url} =~ /,|%2C/) {
            $_->{name} .= ', ' . $areas_info->{$_->{parent_area}}{name};
        }
    }

    $c->stash->{areas_info} = $areas_info;
    my @keys = sort { strcoll($areas_info->{$a}{name}, $areas_info->{$b}{name}) } keys %$areas_info;
    $c->stash->{areas_info_sorted} = [ map { $areas_info->{$_} } @keys ];

    eval {
        my $data = File::Slurp::read_file(
            FixMyStreet->path_to( '../data/all-reports.json' )->stringify
        );
        my $j = JSON->new->utf8->decode($data);
        $c->stash->{fixed} = $j->{fixed};
        $c->stash->{open} = $j->{open};
    };
    if ($@) {
        $c->stash->{message} = _("There was a problem showing the All Reports page. Please try again later.");
        $c->stash->{template} = 'errors/generic.html';
    }
}

=head2 index

Show the summary page for a particular council.

=cut

sub council : Path : Args(1) {
    my ( $self, $c, $council ) = @_;
    $c->detach( 'ward', [ $council ] );
}

=head2 index

Show the summary page for a particular ward.

=cut

sub ward : Path : Args(2) {
    my ( $self, $c, $council, $ward ) = @_;

    $c->forward( 'council_check', [ $council ] );
    $c->forward( 'ward_check', [ $ward ] )
        if $ward;
    $c->forward( 'load_parent' );
    $c->forward( 'load_and_group_problems' );
    $c->forward( 'sort_problems' );

    $c->stash->{rss_url} = '/rss/reports/'
        . $c->cobrand->short_name( $c->stash->{council}, $c->stash->{areas_info} );
    $c->stash->{rss_url} .= '/' . $c->cobrand->short_name( $c->stash->{ward} )
        if $c->stash->{ward};
}

sub rss_council : Regex('^rss/(reports|area)$') : Args(1) {
    my ( $self, $c, $council ) = @_;
    $c->detach( 'rss_ward', [ $council ] );
}

sub rss_ward : Regex('^rss/(reports|area)$') : Args(2) {
    my ( $self, $c, $council, $ward ) = @_;

    my ( $rss ) = $c->req->captures->[0];

    $c->stash->{rss} = 1;

    $c->forward( 'council_check', [ $council ] );
    $c->forward( 'ward_check',    [ $ward    ] ) if $ward;

    if ($rss eq 'area' && $c->stash->{council}{type} ne 'DIS' && $c->stash->{council}{type} ne 'CTY') {
        # Two possibilites are the same for one-tier councils, so redirect one to the other
        $c->detach( 'redirect_area' );
    }

    my $url =       $c->cobrand->short_name( $c->stash->{council} );
    $url   .= '/' . $c->cobrand->short_name( $c->stash->{ward}    ) if $c->stash->{ward};
    $c->stash->{qs} = "/$url";

    my @params;
    push @params, $c->stash->{council}->{id} if $rss eq 'reports';
    push @params, $c->stash->{ward}
        ? $c->stash->{ward}->{id}
        : $c->stash->{council}->{id};
    $c->stash->{db_params} = [ @params ];

    if ( $rss eq 'area' && $c->stash->{ward} ) {
        # All problems within a particular ward
        $c->stash->{type}         = 'area_problems';
        $c->stash->{title_params} = { NAME => $c->stash->{ward}{name} };
        $c->stash->{db_params}    = [ $c->stash->{ward}->{id} ];
    } elsif ( $rss eq 'area' ) {
        # Problems within a particular council
        $c->stash->{type}         = 'area_problems';
        $c->stash->{title_params} = { NAME => $c->stash->{council}{name} };
        $c->stash->{db_params}    = [ $c->stash->{council}->{id} ];
    } elsif ($c->stash->{ward}) {
        # Problems sent to a council, restricted to a ward
        $c->stash->{type} = 'ward_problems';
        $c->stash->{title_params} = { COUNCIL => $c->stash->{council}{name}, WARD => $c->stash->{ward}{name} };
        $c->stash->{db_params} = [ $c->stash->{council}->{id}, $c->stash->{ward}->{id} ];
    } else {
        # Problems sent to a council
        $c->stash->{type} = 'council_problems';
        $c->stash->{title_params} = { COUNCIL => $c->stash->{council}{name} };
        $c->stash->{db_params} = [ $c->stash->{council}->{id}, $c->stash->{council}->{id} ];
    }

    # Send on to the RSS generation
    $c->forward( '/rss/output' );
}

=head2 council_check

This action checks the council name (or code) given in a URI exists, is valid
and so on. If it is, it stores the Area in the stash, otherwise it redirects
to the all reports page.

=cut

sub council_check : Private {
    my ( $self, $c, $q_council ) = @_;

    $q_council =~ s/\+/ /g;
    $q_council =~ s/\.html//;

    # Manual misspelling redirect
    if ($q_council =~ /^rhondda cynon taff$/i) {
        my $url = $c->uri_for( '/reports/rhondda+cynon+taf' );
        $c->res->redirect( $url );
        $c->detach();
    }

    # Check cobrand specific incantations - e.g. ONS codes for UK,
    # Oslo/ kommunes sharing a name in Norway
    return if $c->cobrand->reports_council_check( $c, $q_council );

    # If we're passed an ID number (don't think this is used anywhere, it
    # certainly shouldn't be), just look that up on MaPit and redirect
    if ($q_council =~ /^\d+$/) {
        my $council = mySociety::MaPit::call('area', $q_council);
        $c->detach( 'redirect_index') if $council->{error};
        $c->stash->{council} = $council;
        $c->detach( 'redirect_area' );
    }

    # We must now have a string to check
    my @area_types = $c->cobrand->area_types;
    my $areas = mySociety::MaPit::call( 'areas', $q_council,
        type => \@area_types,
        min_generation => $c->cobrand->area_min_generation
    );
    if (keys %$areas == 1) {
        ($c->stash->{council}) = values %$areas;
        return;
    } else {
        foreach (keys %$areas) {
            if ($areas->{$_}->{name} eq $q_council || $areas->{$_}->{name} =~ /^\Q$q_council\E (Borough|City|District|County) Council$/) {
                $c->stash->{council} = $areas->{$_};
                return;
            }
        }
    }

    # No result, bad council name.
    $c->detach( 'redirect_index' );
}

=head2 ward_check

This action checks the ward name from a URI exists and is part of the right
parent, already found with council_check. It either stores the ward Area if
okay, or redirects to the council page if bad.
This is currently only used in the UK, hence the use of mySociety::VotingArea.

=cut

sub ward_check : Private {
    my ( $self, $c, $ward ) = @_;

    $ward =~ s/\+/ /g;
    $ward =~ s/\.html//;

    my $council = $c->stash->{council};

    my $qw = mySociety::MaPit::call('areas', $ward,
        type => $mySociety::VotingArea::council_child_types,
        min_generation => $c->cobrand->area_min_generation
    );
    foreach my $id (sort keys %$qw) {
        if ($qw->{$id}->{parent_area} == $council->{id}) {
            $c->stash->{ward} = $qw->{$id};
            return;
        }
    }
    # Given a false ward name
    $c->detach( 'redirect_area' );
}

sub load_parent : Private {
    my ( $self, $c ) = @_;

    my $council = $c->stash->{council};
    my $areas_info;
    if ($council->{parent_area}) {
        $c->stash->{areas_info} = mySociety::MaPit::call('areas', [ $council->{id}, $council->{parent_area} ])
    } else {
        $c->stash->{areas_info} = { $council->{id} => $council };
    }
}

sub load_and_group_problems : Private {
    my ( $self, $c ) = @_;

    my $where = {
        state => [ 'confirmed', 'fixed' ]
    };
    my @extra_cols = ();
    if ($c->stash->{ward}) {
        $where->{areas} = { 'like', '%' . $c->stash->{ward}->{id} . '%' }; # FIXME Check this is secure
        push @extra_cols, 'title', 'detail';
    } elsif ($c->stash->{council}) {
        $where->{areas} = { 'like', '%' . $c->stash->{council}->{id} . '%' };
        push @extra_cols, 'title', 'detail';
    }
    my $problems = $c->cobrand->problems->search(
        $where,
        {
            columns => [
                'id', 'council', 'state', 'areas',
                { duration => { extract => "epoch from current_timestamp-lastupdate" } },
                { age      => { extract => "epoch from current_timestamp-confirmed"  } },
                @extra_cols,
            ],
            order_by => { -desc => 'id' },
        }
    );
    $problems = $problems->cursor; # Raw DB cursor for speed

    my ( %fixed, %open );
    my $re_councils = join('|', keys %{$c->stash->{areas_info}});
    my @cols = ( 'id', 'council', 'state', 'areas', 'duration', 'age', 'title', 'detail' );
    while ( my @problem = $problems->next ) {
        my %problem = zip @cols, @problem;
        if ( !$problem{council} ) {
            # Problem was not sent to any council, add to possible councils
            $problem{councils} = 0;
            while ($problem{areas} =~ /,($re_councils)(?=,)/g) {
                add_row( \%problem, $1, \%fixed, \%open );
            }
        } else {
            # Add to councils it was sent to
            (my $council = $problem{council}) =~ s/\|.*$//;
            my @council = split( /,/, $council );
            $problem{councils} = scalar @council;
            foreach ( @council ) {
                next if $c->stash->{council} && $_ != $c->stash->{council}->{id};
                add_row( \%problem, $_, \%fixed, \%open );
            }
        }
    }

    $c->stash->{fixed} = \%fixed;
    $c->stash->{open} = \%open;

    return 1;
}

sub sort_problems : Private {
    my ( $self, $c ) = @_;

    my $id = $c->stash->{council}->{id};
    my $fixed = $c->stash->{fixed};
    my $open = $c->stash->{open};

    foreach (qw/new old/) {
        $c->stash->{fixed}{$id}{$_} = [ sort { $a->{duration} <=> $b->{duration} } @{$fixed->{$id}{$_}} ]
            if $fixed->{$id}{$_};
    }
    foreach (qw/new older unknown/) {
        $c->stash->{open}{$id}{$_} = [ sort { $a->{age} <=> $b->{age} } @{$open->{$id}{$_}} ]
            if $open->{$id}{$_};
    }
}

sub redirect_index : Private {
    my ( $self, $c ) = @_;
    my $url = '/reports';
    $c->res->redirect( $c->uri_for($url) );
}

sub redirect_area : Private {
    my ( $self, $c ) = @_;
    my $url = '';
    $url   .= "/rss" if $c->stash->{rss};
    $url   .= '/reports';
    $url   .= '/' . $c->cobrand->short_name( $c->stash->{council} );
    $url   .= '/' . $c->cobrand->short_name( $c->stash->{ward} )
        if $c->stash->{ward};
    $c->res->redirect( $c->uri_for($url) );
}

my $fourweeks = 4*7*24*60*60;
sub add_row {
    my ( $problem, $council, $fixed, $open ) = @_;
    my $duration_str = ( $problem->{duration} > 2 * $fourweeks ) ? 'old' : 'new';
    my $type = ( $problem->{duration} > 2 * $fourweeks )
        ? 'unknown'
        : ($problem->{age} > $fourweeks ? 'older' : 'new');
    # Fixed problems are either old or new
    push @{$fixed->{$council}{$duration_str}}, $problem if $problem->{state} eq 'fixed';
    # Open problems are either unknown, older, or new
    push @{$open->{$council}{$type}}, $problem if $problem->{state} eq 'confirmed';
}

=head1 AUTHOR

Matthew Somerville

=head1 LICENSE

Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
Licensed under the Affero GPL.

=cut

__PACKAGE__->meta->make_immutable;

1;

