#!/usr/bin/perl -w -I../perllib

# open311.cgi:
# Open311 server API for Open311 clients
#
# http://open311.org/
# http://wiki.open311.org/GeoReport_v2
# http://fixmystreet.org.nz/api
#
# Copyright (c) 2011 Petter Reinholdtsen, some rights reserved.
# Email: pere@hungry.com

use strict;
use warnings;

use Standard;

use URI::Escape;
use Page;

sub main {
    my $q = shift;
    my $all = $q->param('all') || 0;
    my $rss = $q->param('rss') || '';
    my $path_info = $ENV{'PATH_INFO'}; # PATH_INFO = '/services.xml'
    my ($format) = $path_info =~ m/\.(xml|json)/;
    if ($path_info =~ m%^/services%) {
        my $jurisdiction_id = $q->param('jurisdiction_id') || '';
        get_services($q, $jurisdiction_id, $format);
    } else {
        show_documentation($q);
    }
}
Page::do_fastcgi(\&main);

sub show_documentation {
    my $q = shift;

    print $q->header(-charset => 'utf-8', -content_type => 'text/html');
    print $q->p(_("Open311 API for FixMyStreet"));

    print $q->li("http://open311.org/");
    print $q->li("http://wiki.open311.org/GeoReport_v2");
}

sub get_services {
    my ($q, $jurisdiction_id, $format) = @_;

    print $q->header(-charset => 'utf-8', -content_type => 'text/plain');
    for my $env (sort keys %ENV) {
       print "$env = '$ENV{$env}'\n";
    };
}
