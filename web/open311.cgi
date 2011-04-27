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

use JSON;
use URI::Escape;
use Page;

sub main {
    my $q = shift;
    my $all = $q->param('all') || 0;
    my $rss = $q->param('rss') || '';
    # Like PATH_INFO = '/services.xml'
    my $path_info = $ENV{'PATH_INFO'};
    if ($path_info =~ m%^/v2/discovery.(xml|json)$%) {
        my ($format) = $1;
        return get_discovery($q, $format);
    } elsif ($path_info =~ m%^/v2/services.(xml|json)$%) {
        my ($format) = $1;
        return get_services($q, $format);
    } elsif ($path_info =~ m%^/v2/requests/(\d+).(xml|json)$%) {
        my ($id, $format) = ($1, $2);
        return get_requests($q, $format);
    } else {
        return show_documentation($q);
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

sub get_discovery {
    my ($q, $format) = @_;
    my $contact_email = 'fiksgatami@rt.nuug.no';
    my $prod_url = 'http://www.fiksgatami.no/open311';
    my $test_url = 'http://fiksgatami-dev.nuug.no/open311';
    my $prod_changeset = '2011-04-08T00:00:00Z';
    my $test_changeset = $prod_changeset;
    my $spec_url = 'http://wiki.open311.org/GeoReport_v2';
    my $info =
    {
        'contact' => "Send email to $contact_email.",
        'changeset' => $prod_changeset,
        # XXX rewrite to match
        'key_service' =>"Read access is open to all according to our \u003Ca href='/open_data' target='_blank'\u003Eopen data license\u003C/a\u003E. For write access either: 1. return the 'guid' cookie on each call (unique to each client) or 2. use an api key from a user account which can be generated here: http://seeclickfix.com/register The unversioned url will always point to the latest supported version.",
        "endpoints" =>
            [
             {'formats' => ["text/xml",
                            "application/json",
                            "text/html"],
              'type' => 'production',
              'changeset' => $prod_changeset,
              'url' => $prod_url,
              'specification' => $spec_url},
             {'formats' => ['text/xml',
                            'application/json',
                            'text/html'],
              'type' => 'test',
              'changeset' => $test_changeset,
              'url' => "$test_url",
              'specification' => $spec_url},
            ]
    };
    format_output($q, $format, $info);
}

sub get_services {
    my ($q, $format) = @_;
    my $jurisdiction_id = $q->param('jurisdiction_id') || '';
    test_dump($q);
}
sub get_requests {
    my ($q, $format) = @_;
    test_dump($q);
}

sub format_output {
    my ($q, $format, $hashref) = @_;
    if ('json' eq $format) {
        print $q->header( -type => 'application/json; charset=utf-8' );
        print JSON::to_json($hashref);
    } elsif ('xml' eq $format) {
        print $q->header( -type => 'text/xml; charset=utf-8' );
        # FIXME
    } else {
        error();
    }
}

sub test_dump {
    my ($q) = @_;
    print $q->header(-charset => 'utf-8', -content_type => 'text/plain');
    for my $env (sort keys %ENV) {
       print "$env = '$ENV{$env}'\n";
    };
}
