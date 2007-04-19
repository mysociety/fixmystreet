#!/usr/bin/perl -w

# report.cgi:
# Display summary reports for Neighbourhood Fix-It
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: report.cgi,v 1.2 2007-04-19 11:49:54 matthew Exp $

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
use mySociety::Web qw(ent);

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
    my %out;
    my $problem = select_all(
        "select id, title, detail, council, state from problem
        where state in ('confirmed', 'fixed') and council is not null
	order by council, created
    ");
    foreach my $row (@$problem) {
        my $council = $row->{council};
        $council =~ s/\|.*//;
        my @council = split /,/, $council;
        foreach (@council) {
            push @{$out{$_}{$row->{state}}}, [ $row->{id}, $row->{title}, $row->{detail} ];
        }
    }
    my $a = mySociety::MaPit::get_voting_areas_info([keys %out]);
    print Page::header($q, 'Summary reports');
    print $q->p('This page currently simply shows a summary of all reports on this site.
In the future, we hope to increase the functionality of this section.');
    foreach (keys %out) {
        print '<h2>' . $a->{$_}->{name} . "</h2>\n";
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
        print '<br><small>' . ent($_->[2]) . '</small>' if $all;
        print '</li>';
    }
    print '</ul>';
}
