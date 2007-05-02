#!/usr/bin/perl -w

# report.cgi:
# Display summary reports for Neighbourhood Fix-It
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: report.cgi,v 1.9 2007-05-02 10:31:42 matthew Exp $

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
    $all = 0 unless $one_council;
    my @params;
    my $where_extra;
    if ($one_council) {
        push @params, $one_council;
        $where_extra = "and council = ?";
    }
    my %out;
    my $problem = select_all(
        "select id, title, detail, council, state from problem
        where state in ('confirmed', 'fixed') and whensent is not null
        $where_extra
        order by id
    ", @params);
    foreach my $row (@$problem) {
        my $council = $row->{council};
        $council =~ s/\|.*//;
        my @council = split /,/, $council;
        foreach (@council) {
            push @{$out{$_}{$row->{state}}}, [ $row->{id}, $row->{title}, $row->{detail}, @council>1 ];
        }
    }
    my $areas_info = mySociety::MaPit::get_voting_areas_info([keys %out]);
    print Page::header($q, 'Summary reports');
    if (!$one_council) {
        print $q->p('This is a summary of all reports on this site, select \'show only\' to see the reports for just one council.');
    } else {
        print $q->p('This is a summary of all reports for one council. You can ' .
            $q->a({href => NewURL($q, all=>1) }, 'see more details') .
            ' or go back and ' .
            $q->a({href => NewURL($q, all=>undef, council=>undef) }, 'show all councils') .
            '.');
    }
    foreach (sort { $areas_info->{$a}->{name} cmp $areas_info->{$b}->{name} } keys %out) {
        print '<h2>' . $areas_info->{$_}->{name};
        if (!$one_council) {
            print ' ' . $q->small('('.$q->a({href => NewURL($q, 'council'=>$_) }, 'show only').')');
        }
        print "</h2>\n";
        list_problems('Problems', $out{$_}{confirmed}, $all) if $out{$_}{confirmed};
        list_problems('Fixed', $out{$_}{fixed}, $all) if $out{$_}{fixed};
    }
    print Page::footer();
}
Page::do_fastcgi(\&main);

sub list_problems {
    my ($title, $problems, $all) = @_;
    print "<h3>$title</h3>\n<ul>";
    foreach (@$problems) {
        print '<li><a href="/?id=' . $_->[0] . '">';
        print ent($_->[1]);
        print '</a>';
        print ' <small>(sent to both)</small>' if $_->[3];
        print '<br><small>' . ent($_->[2]) . '</small>' if $all;
        print '</li>';
    }
    print '</ul>';
}
