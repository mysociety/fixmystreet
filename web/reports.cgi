#!/usr/bin/perl -w -I../perllib

# report.cgi:
# Display summary reports for FixMyStreet
# And RSS feeds for those reports etc.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: reports.cgi,v 1.41 2009-12-08 11:13:30 louise Exp $

use strict;
use Standard;
use URI::Escape;
use FixMyStreet::Alert;
use mySociety::MaPit;
use mySociety::Web qw(ent NewURL);
use mySociety::VotingArea;

sub main {
    my $q = shift;
    my $all = $q->param('all') || 0;
    my $rss = $q->param('rss') || '';
    my $cobrand = Page::get_cobrand($q);
    # Look up council name, if given
    my $q_council = $q->param('council') || '';
    my $base_url = Cobrand::base_url($cobrand);
    # Manual misspelling redirect
    if ($q_council =~ /^rhondda cynon taff$/i) {
        print $q->redirect($base_url . '/reports/Rhondda+Cynon+Taf');
        return;
    }

    my ($one_council, $area_type, $area_name);
    if ($q_council =~ /^(\d\d)([a-z]{2})?([a-z]{2})?$/i) {
        my $va_info = mySociety::MaPit::call('area', uc $q_council);
        if ($va_info->{error}) { # Given a bad/old ONS code
            print $q->redirect($base_url . '/reports');
            return;
        }
        $area_name = Page::short_name($va_info->{name});
        if (length($q_council) == 6) {
            $va_info = mySociety::MaPit::call('area', $va_info->{parent_area});
            $area_name = Page::short_name($va_info->{name}) . '/' . $area_name;
        }
        $rss = '/rss' if $rss;
        print $q->redirect($base_url . $rss . '/reports/' . $area_name);
        return;
    } elsif ($q_council =~ /\D/) {
        my $areas = mySociety::MaPit::call('areas', $q_council, type => $mySociety::VotingArea::council_parent_types, min_generation=>10 );
        if (keys %$areas == 1) {
            ($one_council) = keys %$areas;
            $area_type = $areas->{$one_council}->{type};
            $area_name = $areas->{$one_council}->{name};
        } else {
            foreach (keys %$areas) {
                if ($areas->{$_}->{name} =~ /^\Q$q_council\E (Borough|City|District|County) Council$/) {
                    $one_council = $_;
                    $area_type = $areas->{$_}->{type};
                    $area_name = $q_council;
                }
            }
        }
        if (!$one_council) { # Given a false council name
            print $q->redirect($base_url . '/reports');
            return;
        }
    } elsif ($q_council =~ /^\d+$/) {
        my $va_info = mySociety::MaPit::call('area', $q_council);
        if ($va_info->{error}) {
            print $q->redirect($base_url . '/reports');
            return;
        }
        $area_name = $va_info->{name};
        print $q->redirect($base_url . '/reports/' . Page::short_name($area_name));
        return;
    }
    $all = 0 unless $one_council;

    # Look up ward name, if given
    my $q_ward = $q->param('ward') || '';
    my $ward;
    if ($one_council && $q_ward) {
        my $qw = mySociety::MaPit::call('areas', $q_ward, type => $mySociety::VotingArea::council_child_types, min_generation => 10);
        foreach my $id (sort keys %$qw) {
            if ($qw->{$id}->{parent_area} == $one_council) {
                $ward = $id;
                last;
            }
        }
        if (!$ward) { # Given a false ward name
            print $q->redirect($base_url . '/reports/' . Page::short_name($q_council));
            return;
        }
    }

    # RSS - reports for sent reports, area for all problems in area
    if ($rss && $one_council) {
        my $url = Page::short_name($q_council);
        $url .= '/' . Page::short_name($q_ward) if $ward;
        if ($rss eq 'area' && $area_type ne 'DIS' && $area_type ne 'CTY') {
            # Two possibilites are the same for one-tier councils, so redirect one to the other
            print $q->redirect($base_url . '/rss/reports/' . $url);
            return;
        }
        my $type = 'council_problems'; # Problems sent to a council
        my (@params, %title_params);
        $title_params{COUNCIL} = $area_name;
        push @params, $one_council if $rss eq 'reports';
        push @params, $ward ? $ward : $one_council;
        if ($ward && $rss eq 'reports') {
            $type = 'ward_problems'; # Problems sent to a council, restricted to a ward
            $title_params{WARD} = $q_ward;
        } elsif ($rss eq 'area') {
            $title_params{NAME} = $ward ? $q_ward : $q_council;
            $type = 'area_problems'; # Problems within an area
        }
        print $q->header( -type => 'application/xml; charset=utf-8' );
        my $xsl = Cobrand::feed_xsl($cobrand);
        my $out = FixMyStreet::Alert::generate_rss($type, $xsl, "/$url", \@params, \%title_params, $cobrand, $q);
        $out =~ s/matthew.fixmystreet/emptyhomes.matthew.fixmystreet/g if $q->{site} eq 'emptyhomes';
        print $out;
        return;
    }

    my $areas_info;
    if ($one_council) {
        $areas_info = mySociety::MaPit::call('areas', $one_council);
    } else {
        # Show all councils on main report page
        my $ignore = 'LGD';
        $ignore .= '|CTY' if $q->{site} eq 'emptyhomes';
        my @types = grep { !/$ignore/ } @$mySociety::VotingArea::council_parent_types;
        $areas_info = mySociety::MaPit::call('areas', [ @types ], min_generation=>10 );
    }

    my $problems = Problems::council_problems($ward, $one_council); 

    my (%fixed, %open);
    my $re_councils = join('|', keys %$areas_info);
    foreach my $row (@$problems) {
        if (!$row->{council}) {
            # Problem was not sent to any council, add to possible councils
            while ($row->{areas} =~ /,($re_councils)(?=,)/g) {
                add_row($row, 0, $1, \%fixed, \%open);
            }
        } else {
            # Add to councils it was sent to
            $row->{council} =~ s/\|.*$//;
            my @council = split /,/, $row->{council};
            foreach (@council) {
                next if $one_council && $_ != $one_council;
                add_row($row, scalar @council, $_, \%fixed, \%open);
            }
        }
    }

    if (!$one_council) {
        print Page::header($q, title=>_('Summary reports'), expires=>'+1h');
        print $q->p(
            _('This is a summary of all reports on this site; select a particular council to see the reports sent there.'), ' ',
            _('Greyed-out lines are councils that no longer exist.')
        );
        my $c = 0;
        print '<table cellpadding="3" cellspacing="1" border="0">';
        print '<tr><th>' . _('Name') . '</th><th>' . _('New problems') . '</th><th>' . _('Older problems') . '</th>';
        if ($q->{site} ne 'emptyhomes') {
            print '<th>' . _('Old problems,<br>state unknown') . '</th>';
        }
        print '<th>' . _('Recently fixed') . '</th><th>' . _('Older fixed') . '</th></tr>';
        foreach (sort { $areas_info->{$a}->{name} cmp $areas_info->{$b}->{name} } keys %$areas_info) {
            print '<tr align="center"';
            ++$c;
            if ($areas_info->{$_}->{generation_high}==10) {
                print ' class="gone"';
            } elsif ($c%2) {
                print ' class="a"';
            }
            my $url = Page::short_name($areas_info->{$_}->{name});
            my $cobrand_url = Cobrand::url($cobrand, "/reports/$url", $q);
            print '><td align="left"><a href="' . $cobrand_url . '">' .
                $areas_info->{$_}->{name} . '</a></td>';
            summary_cell(\@{$open{$_}{new}});
            if ($q->{site} eq 'emptyhomes') {
                my $c = 0;
                $c += @{$open{$_}{older}} if $open{$_}{older};
                $c += @{$open{$_}{unknown}} if $open{$_}{unknown};
                summary_cell($c);
            } else {
                summary_cell(\@{$open{$_}{older}});
                summary_cell(\@{$open{$_}{unknown}});
            }
            summary_cell(\@{$fixed{$_}{new}});
            summary_cell(\@{$fixed{$_}{old}});
            print "</tr>\n";
        }
        print '</table>';
    } else {
        my $name = $areas_info->{$one_council}->{name};
        if (!$name) {
            print Page::header($q, title=>_("Summary reports"));
            print "Council with identifier " . ent($one_council). " not found. ";
            print $q->a({href => Cobrand::url($cobrand, '/reports', $q) }, 'Show all councils');
            print ".";
        } else {
            my $rss_url = '/rss/reports/' . Page::short_name($name);
            my $thing = _('council');
            if ($ward) {
                $rss_url .= '/' . Page::short_name($q_ward);
                $thing = 'ward';
                $name = ent($q_ward) . ", $name";
            }
            my $all_councils_report = Cobrand::all_councils_report($cobrand);

            my %vars = (
                rss_title => _('RSS feed'),
                rss_alt => sprintf(_('RSS feed of problems in this %s'), $thing),
                rss_url => Cobrand::url($cobrand, $rss_url, $q),
                url_home => Cobrand::url($cobrand, '/', $q),
                summary_title => $all_councils_report
                    ? sprintf(_('This is a summary of all reports for one %s.'), $thing)
                    : sprintf(_('This is a summary of all reports for this %s.'), $thing),
                name => $name,
            );
            if ($all && ! $all_councils_report) {
                $vars{summary_line} = sprintf(_('You can <a href="%s">see less detail</a>.'), Cobrand::url($cobrand, NewURL($q), $q));
            } elsif (! $all_councils_report) {
                $vars{summary_line} = sprintf(_('You can <a href="%s">see more details</a>.'), Cobrand::url($cobrand, NewURL($q, all=>1), $q));
            } elsif ($all) {
                $vars{summary_line} = sprintf(_('You can <a href="%s">see less detail</a> or go back and <a href="/reports">show all councils</a>.'), Cobrand::url($cobrand, NewURL($q), $q));
            } else {
                $vars{summary_line} = sprintf(_('You can <a href="%s">see more details</a> or go back and <a href="/reports">show all councils</a>.'), Cobrand::url($cobrand, NewURL($q, all=>1), $q));
            }

            if ($open{$one_council}) {
                my $col = list_problems($q, _('New problems'), $open{$one_council}{new}, $all, 0);
                my $old = [];
                if ($q->{site} eq 'emptyhomes') {
                    push @$old, @{$open{$one_council}{older}} if $open{$one_council}{older};
                    push @$old, @{$open{$one_council}{unknown}} if $open{$one_council}{unknown};
                } else {
                    $old = $open{$one_council}{older};
                }
                $col .= list_problems($q, _('Older problems'), $old, $all, 0);
                if ($q->{site} ne 'emptyhomes') {
                    $col .= list_problems($q, _('Old problems, state unknown'), $open{$one_council}{unknown}, $all, 0);
                }
                $vars{col_problems} = $col;
            }
            if ($fixed{$one_council}) {
                my $col = list_problems($q, _('Recently fixed'), $fixed{$one_council}{new}, $all, 1);
                $col .= list_problems($q, _('Old fixed'), $fixed{$one_council}{old}, $all, 1);
                $vars{col_fixed} = $col;
            }
            print Page::header($q, context => 'reports', title=>sprintf(_('%s - Summary reports'), $name), rss => [ sprintf(_('Problems within %s, FixMyStreet'), $name), Cobrand::url($cobrand, $rss_url, $q) ]);
            print Page::template_include('reports', $q, Page::template_root($q), %vars);
        }
    }
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

sub add_row {
    my ($row, $councils, $council, $fixed, $open) = @_;
    my $fourweeks = 4*7*24*60*60;
    my $duration = ($row->{duration} > 2 * $fourweeks) ? 'old' : 'new';
    my $type = ($row->{duration} > 2 * $fourweeks)
        ? 'unknown'
        : ($row->{age} > $fourweeks ? 'older' : 'new');
    $row->{councils} = $councils;
    #Fixed problems are either old or new
    push @{$fixed->{$council}{$duration}}, $row if $row->{state} eq 'fixed';
    # Open problems are either unknown, older, or new
    push @{$open->{$council}{$type}}, $row if $row->{state} eq 'confirmed';
}

sub summary_cell {
    my $c = shift;
    $c = 0 unless defined $c;
    $c = @$c if ref($c) eq 'ARRAY';
    print '<td>' . $c . '</td>';
}

sub list_problems {
    my ($q, $title, $problems, $all, $fixed) = @_;
    return '' unless $problems;
    my $cobrand = Page::get_cobrand($q);
    my $out = "<h3>$title</h3>\n<ul>";
    foreach (sort { $fixed ? ($a->{duration} <=> $b->{duration}) : ($a->{age} <=> $b->{age}) } @$problems) {
        my $url = Cobrand::url($cobrand, "/report/" .  $_->{id}, $q); 
        $out .= '<li><a href="' . $url . '">';
        $out .= ent($_->{title});
        $out .= '</a>';
        $out .= ' <small>(sent to both)</small>' if $_->{councils}>1;
        $out .= ' <small>(not sent to council)</small>' if $_->{councils}==0 && $q->{site} ne 'emptyhomes';
        $out .= '<br><small>' . ent($_->{detail}) . '</small>' if $all;
        $out .= '</li>';
    }
    $out .= '</ul>';
    return $out;
}

