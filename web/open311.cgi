#!/usr/bin/perl -w -I../perllib

# open311.cgi:
# Open311 server API for Open311 clients
#
# http://open311.org/
# http://wiki.open311.org/GeoReport_v2
# http://fixmystreet.org.nz/api
# http://seeclickfix.com/open311/
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
        'endpoints' =>
            [{'formats' => ['text/xml',
                            'application/json',
                            'text/html'],
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

# Example
# http://seeclickfix.com/open311/services.html?lat=32.1562864999991&lng=-110.883806
sub get_services {
    my ($q, $format) = @_;
    my $jurisdiction_id = $q->param('jurisdiction_id') || '';
    my $lat = $q->param('lat') || '';
    my $lon = $q->param('lon') || '';

    my @area_types = Cobrand::area_types($cobrand);

    my $all_councils = mySociety::MaPit::call('point',
                                              "4326/$lon,$lat",
                                              type => \@area_types);

    # Look up categories for this council or councils
    my $category = '';
    my (%council_ok, @categories);
    my $categories =
        select_all("SELECT area_id, category FROM contacts ".
                   " WHERE deleted='f' and area_id IN (" .
                   join(',', keys %$all_councils) . ')');
    my $categorynum = 0;
    for my $categoryref ( sort {$a->{category} cmp $b->{category} }
                          @$categories) {
        my $categoryname = $categoryref->{category};
        $categorynum++; # FIXME need to figure out a good number to use
        push(@services,
             {
                 'service_name' => $categoryname,
                 'description' => '',
                 'service_code' => $categorynum,
                 'metadata' => 'true',
                 'type' => 'realtime',
                 'group' => '',
                 'keywords' => '',
             }
            );
    }
    if ('json' eq $format) {
        print $q->header( -type => 'application/json; charset=utf-8' );
        print JSON::to_json($hashref);
    } else {
        # FIXME, add XML support
    }
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
        print $q->header( -type => 'application/xml; charset=utf-8' );
        # FIXME
        print as_xml({'discovery' => $hashref});
    } else {
        error();
    }
}

sub as_xml {
    my ($hashref) = @_;
    my $xml = '';
    for my $key (sort keys %{$hashref}) {
        $xml .= "<$key>";
        if ('HASH' eq ref $hashref->{$key}) {
            $xml .= as_xml($hashref->{$key});
        } elsif ('ARRAY' eq ref $hashref->{$key}) {
            for my $row (@{$hashref->{$key}}) {
                $xml .= as_xml($row);
            }
        } else {
            $xml .= $hashref->{$key};
        }
        $xml .= "</$key>";
    }
    return $xml;
}

sub test_dump {
    my ($q) = @_;
    print $q->header(-charset => 'utf-8', -content_type => 'text/plain');
    for my $env (sort keys %ENV) {
       print "$env = '$ENV{$env}'\n";
    };
}
