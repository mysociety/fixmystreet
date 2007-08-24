#!/usr/bin/perl -w

# report.cgi:
# Display summary reports for FixMyStreet
# And RSS feeds for those reports etc.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: reports.cgi,v 1.5 2007-08-24 23:37:15 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use URI::Escape;

use Page;
use mySociety::Alert;
use mySociety::Config;
use mySociety::DBHandle qw(dbh select_all);
use mySociety::MaPit;
use mySociety::Web qw(ent NewURL);
use mySociety::VotingArea;

BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
    mySociety::DBHandle::configure(
        Name => mySociety::Config::get('BCI_DB_NAME'),
        User => mySociety::Config::get('BCI_DB_USER'),
        Password => mySociety::Config::get('BCI_DB_PASS'),
        Host => mySociety::Config::get('BCI_DB_HOST', undef),
        Port => mySociety::Config::get('BCI_DB_PORT', undef)
    );
}

sub main {
    my $q = shift;
    my $all = $q->param('all') || 0;
    my $rss = $q->param('rss') || '';

    # Look up council name, if given
    my $q_council = $q->param('council') || '';
    my ($one_council, $area_type);
    if ($q_council =~ /\D/) {
        (my $qc = $q_council) =~ s/ and / & /;
        $qc = mySociety::MaPit::get_voting_area_by_name("$qc ", $mySociety::VotingArea::council_parent_types);
        if (keys %$qc == 1) {
            ($one_council) = keys %$qc;
            $area_type = $qc->{$one_council}->{type};
        }
        if (!$one_council) { # Given a false council name
            print $q->redirect('/reports');
            return;
        }
    } elsif ($q_council =~ /^\d+$/) {
        $one_council = $q_council;
    }
    $all = 0 unless $one_council;

    # Look up ward name, if given
    my $q_ward = $q->param('ward') || '';
    my $ward;
    if ($one_council && $q_ward) {
        my $qw = mySociety::MaPit::get_voting_area_by_name($q_ward, $mySociety::VotingArea::council_child_types);
        foreach my $id (sort keys %$qw) {
            if ($qw->{$id}->{parent_area_id} == $one_council) {
                $ward = $id;
                last;
            }
        }
        if (!$ward) { # Given a false ward name
            print $q->redirect('/reports/' . short_name($q_council));
            return;
        }
    }

    # RSS - reports for sent reports, area for all problems in area
    if ($rss && $one_council) {
        if ($rss eq 'area' && $area_type ne 'DIS' && $area_type ne 'CTY') {
	    # Two possibilites are the same for one-tier councils, so redirect one to the other
            print $q->redirect('/rss/reports/' . short_name($q_council) . ($ward ? '/' . short_name($q_ward) : ''));
            return;
        }
        my $type = 'council_problems'; # Problems sent to a council
        my @params;
        push @params, $one_council if $rss eq 'reports';
        push @params, $ward ? $ward : $one_council;
        if ($ward && $rss eq 'reports') {
            $type = 'ward_problems'; # Problems sent to a council, restricted to a ward
        } elsif ($rss eq 'area') {
            $type = 'area_problems'; # Problems within an area
        }
        my $url = short_name($q_council);
        $url .= '/' . short_name($q_ward) if $ward;
        mySociety::Alert::generate_rss($type, "/$url", @params);
        return;
    }

    my %councils;
    if ($one_council) {
        %councils = ( $one_council => 1 );
    } else {
        # Show all councils on main report page
        %councils = map { $_ => 1 } @{mySociety::MaPit::get_areas_by_type($mySociety::VotingArea::council_parent_types)};
    }

    my @params;
    my $where_extra = '';
    if ($ward) {
        push @params, $ward;
        $where_extra = "and areas like '%,'||?||',%'";
    } elsif ($one_council) {
        push @params, $one_council;
        $where_extra = "and areas like '%,'||?||',%'";
    }
    my $problem = select_all(
        "select id, title, detail, council, state, areas,
        extract(epoch from ms_current_timestamp()-lastupdate) as duration,
        extract(epoch from ms_current_timestamp()-confirmed) as age
        from problem
        where state in ('confirmed', 'fixed')
        $where_extra
        order by id desc
    ", @params);

    our $fourweeks = 4*7*24*60*60;
    our (%fixed, %open);
    sub add_row {
        my ($row, $councils, $council) = @_;
        my $duration = ($row->{duration} > 2 * $fourweeks) ? 'old' : 'new';
        my $type = ($row->{duration} > 2 * $fourweeks)
            ? 'unknown'
            : ($row->{age} > $fourweeks ? 'older' : 'new');
        my $entry = [ $row->{id}, $row->{title}, $row->{detail}, $councils ];
	# Fixed problems are either old or new
        push @{$fixed{$council}{$duration}}, $entry if $row->{state} eq 'fixed';
	# Open problems are either unknown, older, or new
        push @{$open{$council}{$type}}, $entry if $row->{state} eq 'confirmed';
    }

    my $re_councils = join('|', keys %councils);
    foreach my $row (@$problem) {
        if (!$row->{council}) {
	    # Problem was not sent to any council, add to possible councils
            while ($row->{areas} =~ /,($re_councils)(?=,)/go) {
                add_row($row, 0, $1);
            }
        } else {
	    # Add to councils it was sent to
            $row->{council} =~ s/\|.*$//;
            my @council = split /,/, $row->{council};
            foreach (@council) {
                next if $one_council && $_ != $one_council;
                add_row($row, scalar @council, $_);
            }
        }
    }

    my $areas_info = mySociety::MaPit::get_voting_areas_info([keys %councils]);
    if (!$one_council) {
        print Page::header($q, title=>'Summary reports');
        print $q->p(_('This is a summary of all reports on this site; select a particular council to see the reports sent there.'));
        my $c = 0;
        print '<table cellpadding="3" cellspacing="1" border="0">';
        print '<tr><th>Name</th><th>New problems</th><th>Older problems</th>
<th>Old problems,<br>state unknown</th><th>Recently fixed</th><th>Old fixed</th></tr>';
        foreach (sort { $areas_info->{$a}->{name} cmp $areas_info->{$b}->{name} } keys %councils) {
            print '<tr align="center"';
            print ' class="a"' if (++$c%2);
            my $url = short_name($areas_info->{$_}->{name});
            print '><td align="left"><a href="/reports/' . $url . '">' .
                $areas_info->{$_}->{name} . '</a></td>';
            summary_cell(\@{$open{$_}{new}});
            summary_cell(\@{$open{$_}{older}});
            summary_cell(\@{$open{$_}{unknown}});
            summary_cell(\@{$fixed{$_}{new}});
            summary_cell(\@{$fixed{$_}{old}});
            print "</tr>\n";
        }
        print '</table>';
    } else {
        my $name = $areas_info->{$one_council}->{name};
        if (!$name) {
            print Page::header($q, title=>"Summary reports");
            print "Council with identifier " . ent($one_council). " not found. ";
            print $q->a({href => '/reports' }, 'Show all councils');
            print ".";
        } else {
            my $rss_url = '/rss/reports/' . short_name($name);
            my $thing = 'council';
            if ($ward) {
                $rss_url .= '/' . short_name($q_ward);
                $thing = 'ward';
                $name = ent($q_ward) . ", $name";
            }
            print Page::header($q, title=>"$name - Summary reports", rss => [ "Problems within $name, FixMyStreet", $rss_url ]);
            print $q->p(
                $q->a({ href => $rss_url }, '<img align="right" src="/i/feed.png" width="16" height="16" title="RSS feed" alt="RSS feed of problems in this ' . $thing . '" border="0" hspace="4">'),
                'This is a summary of all reports for one ' . $thing . '. You can ' .
                ($all ? 
                    $q->a({href => NewURL($q, council=>undef, all=>undef) }, 'see less detail') :
                    $q->a({href => NewURL($q, council=>undef, all=>1) }, 'see more details')) .
                ' or go back and ' .
                $q->a({href => '/reports' }, 'show all councils') .
                '.');
            print "<h2>$name</h2>\n";
            if ($open{$one_council}) {
                print '<div id="col_problems">';
                list_problems('New problems', $open{$one_council}{new}, $all);
                list_problems('Older problems', $open{$one_council}{older}, $all);
                list_problems('Old problems, state unknown', $open{$one_council}{unknown}, $all);
                print '</div>';
            }
            if ($fixed{$one_council}) {
                print '<div id="col_fixed">';
                list_problems('Recently fixed', $fixed{$one_council}{new}, $all);
                list_problems('Old fixed', $fixed{$one_council}{old}, $all);
                print '</div>';
            }
        }
    }
    print Page::footer();
    dbh()->rollback();
}
Page::do_fastcgi(\&main);

sub summary_cell {
    my $c = shift;
    print $c ? '<td>' . scalar @$c . '</td>' : '<td>0</td>';
}

sub list_problems {
    my ($title, $problems, $all) = @_;
    return unless $problems;
    print "<h3>$title</h3>\n<ul>";
    foreach (@$problems) {
        print '<li><a href="/?id=' . $_->[0] . '">';
        print ent($_->[1]);
        print '</a>';
        print ' <small>(sent to both)</small>' if $_->[3]>1;
        print ' <small>(not sent to council)</small>' if $_->[3]==0;
        print '<br><small>' . ent($_->[2]) . '</small>' if $all;
        print '</li>';
    }
    print '</ul>';
}

sub short_name {
    my $name = shift;
    # Special case Durham as it's the only place with two councils of the same name
    return 'Durham+County' if ($name eq 'Durham County Council');
    return 'Durham+City' if ($name eq 'Durham City Council');
    $name =~ s/ (Borough|City|District|County) Council$//;
    $name =~ s/ Council$//;
    $name =~ s/ & / and /;
    $name = uri_escape($name);
    $name =~ s/%20/+/g;
    return $name;
}

