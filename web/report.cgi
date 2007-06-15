#!/usr/bin/perl -w

# report.cgi:
# Display summary reports for Neighbourhood Fix-It
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: report.cgi,v 1.37 2007-06-15 09:34:45 francis Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Page;
use mySociety::Config;
use mySociety::DBHandle qw(dbh select_all);
use mySociety::MaPit;
use mySociety::Web qw(ent NewURL);

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
    my $one_council = $q->param('council');
    $one_council =~ s/\D//g;
    $all = 0 unless $one_council;
    my @params;
    my $where_extra = '';
    if ($one_council) {
        push @params, $one_council;
        $where_extra = "and council like '%'||?||'%'";
    }
    my (%fixed, %open, %councils);
    my $problem = select_all(
        "select id, title, detail, council, state,
        extract(epoch from ms_current_timestamp()-lastupdate) as duration,
        extract(epoch from ms_current_timestamp()-confirmed) as age
        from problem
        where state in ('confirmed', 'fixed')
            and whensent is not null
        $where_extra
        order by id
    ", @params);
    my $fourweeks = 4*7*24*60*60;
    foreach my $row (@$problem) {
        my ($council, $missing) = $row->{council} =~ /^(.*?)(?:\|(.*))?$/;
        my @council = split /,/, $council;
        my $type = ($row->{duration} > 2 * $fourweeks)
            ? 'unknown'
            : ($row->{age} > $fourweeks ? 'older' : 'new');
        my $duration = ($row->{duration} > 2 * $fourweeks) ? 'old' : 'new';
        foreach (@council) {
            next if $one_council && $_ != $one_council;
            my $entry = [ $row->{id}, $row->{title}, $row->{detail}, scalar @council, $missing ];
            push @{$fixed{$_}{$duration}}, $entry
                if $row->{state} eq 'fixed';
            push @{$open{$_}{$type}}, $entry
                if $row->{state} eq 'confirmed';
            $councils{$_} = 1;
        }
    }
    my $areas_info = mySociety::MaPit::get_voting_areas_info([keys %councils]);
    if (!$one_council) {
        print Page::header($q, title=>'Summary reports');
        print $q->p(_('This is a summary of all reports on this site that have been sent to a council; select a particular council to see the reports sent there.'));
        my $c = 0;
        print '<table cellpadding="3" cellspacing="1" border="0">';
        print '<tr><th>Name</th><th>New problems</th><th>Older problems</th>
<th>Old problems,<br>state unknown</th><th>Recently fixed</th><th>Old fixed</th></tr>';
        foreach (sort { Page::canonicalise_council($areas_info->{$a}->{name}) cmp Page::canonicalise_council($areas_info->{$b}->{name}) } keys %councils) {
            print '<tr align="center"';
            print ' class="a"' if (++$c%2);
            print '><td align="left"><a href="report?council=' . $_ . '">' .
                Page::canonicalise_council($areas_info->{$_}->{name}) . '</a></td>';
            summary_cell(\@{$open{$_}{new}});
            summary_cell(\@{$open{$_}{older}});
            summary_cell(\@{$open{$_}{unknown}});
            summary_cell(\@{$fixed{$_}{new}});
            summary_cell(\@{$fixed{$_}{old}});
            print "</tr>\n";
        }
        print '</table>';
    } else {
        my $name = Page::canonicalise_council($areas_info->{$one_council}->{name});
        if (!$name) {
            print Page::header($q, title=>"Summary reports");
            print "Council with identifier " . ent($one_council). " not found. ";
            print $q->a({href => NewURL($q, all=>undef, council=>undef) }, 'Show all councils');
            print ".";
        } else {
            print Page::header($q, title=>"$name - Summary reports", rss => [ "Problems within $name, Neighbourhood Fix-It", "/rss/council/$one_council" ]);
            print $q->p(
                $q->a({href => "/rss/council/$one_council"}, '<img align="right" src="/i/feed.png" width="16" height="16" title="RSS feed" alt="RSS feed of problems in this council" border="0" hspace="4">'),
                'This is a summary of all reports for one council. You can ' .
                ($all ? 
                    $q->a({href => NewURL($q, all=>undef) }, 'see less details') :
                    $q->a({href => NewURL($q, all=>1) }, 'see more details')) .
                ' or go back and ' .
                $q->a({href => NewURL($q, all=>undef, council=>undef) }, 'show all councils') .
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
        print ' <small>(sent to none)</small>' if $_->[3]==0;
        print '<br><small>' . ent($_->[2]) . '</small>' if $all;
        print '</li>';
    }
    print '</ul>';
}
