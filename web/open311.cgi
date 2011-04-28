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
#
# Issues with Open311
#  * no way to specify which languages are understood by the
#    recipients.  some lang=nb,nn setting should be available.
#  * not obvious how to handle generic requests (ie without lat/lon
#    values).
#  * should service IDs be numeric or not?  Spec do not say, and all
#    examples use numbers.

use strict;
use warnings;

use Standard;

use JSON;
use XML::Simple;
use URI::Escape;
use Page;
use mySociety::DBHandle qw(select_all);

sub main {
    my $q = shift;
    my $all = $q->param('all') || 0;
    my $rss = $q->param('rss') || '';
    # Like PATH_INFO = '/services.xml'
    my $path_info = $ENV{'PATH_INFO'};
    if ($path_info =~ m%^/v2/discovery.(xml|json|html)$%) {
        my ($format) = $1;
        return get_discovery($q, $format);
    } elsif ($path_info =~ m%^/v2/services.(xml|json|html)$%) {
        my ($format) = $1;
        return get_services($q, $format);
    } elsif ($path_info =~ m%^/v2/requests/(\d+).(xml|json|html)$%) {
        my ($id, $format) = ($1, $2);
        return get_request($q, $id, $format);
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

# Example
# http://sandbox.georeport.org/tools/discovery/discovery.xml
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
        'contact' => ["Send email to $contact_email."],
        'changeset' => [$prod_changeset],
        # XXX rewrite to match
        'key_service' => ["Read access is open to all according to our \u003Ca href='/open_data' target='_blank'\u003Eopen data license\u003C/a\u003E. For write access either: 1. return the 'guid' cookie on each call (unique to each client) or 2. use an api key from a user account which can be generated here: http://seeclickfix.com/register The unversioned url will always point to the latest supported version."],
        'endpoints' => [
            {
                'endpoint' => [
                    {
                        'formats' => [
                            {'format' => [ 'text/xml',
                                           'application/json',
                                           'text/html' ]
                            }
                            ],
                        'specification' => [ $spec_url ],
                        'changeset' => [ $prod_changeset ],
                        'url' => [ $prod_url ],
                        'type' => [ 'production' ]
                    },
                    {
                        'formats' => [
                            {
                                'format' => [ 'text/xml',
                                              'application/json',
                                              'text/html' ]
                            }
                            ],
                        'specification' => [ $spec_url ],
                        'changeset' => [ $test_changeset ],
                        'url' => [ $test_url ],
                        'type' => [ 'test' ]
                    }
                    ]
            }
            ]
    };
    format_output($q, $format, {'discovery' => $info});
}

# Example
# http://seeclickfix.com/open311/services.html?lat=32.1562864999991&lng=-110.883806
sub get_services {
    my ($q, $format) = @_;
    my $jurisdiction_id = $q->param('jurisdiction_id') || '';
    my $lat = $q->param('lat') || '';
    my $lon = $q->param('lon') || '';

    my $cobrand = Page::get_cobrand($q);
    my @area_types = Cobrand::area_types($cobrand);

    my $all_councils;
    if ($lat || $lon) {
        $all_councils = mySociety::MaPit::call('point',
                                               "4326/$lon,$lat",
                                               type => \@area_types);
    } else {
        # FIXME Figure out a better way to handle no lat/lon
        $all_councils = { 3 => 'Oslo'};
    }

    # Look up categories for this council or councils
    my $categories =
        select_all("SELECT area_id, category FROM contacts ".
                   " WHERE deleted='f' and area_id IN (" .
                   join(',', keys %$all_councils) . ')');
    my @services;
    for my $categoryref ( sort {$a->{category} cmp $b->{category} }
                          @$categories) {
        my $categoryname = $categoryref->{category};
        push(@services,
             {
                 'service_name' => [ $categoryname ],
                 'description' =>  [ '' ],
                 'service_code' => [ $categoryname ],
                 'metadata' => [ 'true' ],
                 'type' => [ 'realtime' ],
                 'group' => [ '' ],
                 'keywords' => [ '' ],
             }
            );
    }
    format_output($q, $format, {'services' => [{ 'service' => \@services}]});
}

# Example
# http://seeclickfix.com/open311/requests/1.xml?jurisdiction_id=sfgov.org
sub get_request {
    my ($q, $id, $format) = @_;

    # Look up categories for this council or councils
    my $problems =
        select_all("SELECT title, detail, latitude, longitude, state, ".
                   "category, created, lastupdate, ".
                   "(photo is not null) as has_photo FROM problem ".
                   "WHERE state in ('fixed', 'confirmed') and id = ?", $id);
    if (@{$problems}[0]) {
        my $problem = @{$problems}[0];
        my %statusmap = ( 'fixed' => 'closed',
                          'confirmed' => 'open');
        my $info =
        {
            'service_request_id' => [ $id ],
            'description' => [ $problem->{title} ."\n" . $problem->{detail} ],
            'lat' => [ $problem->{latitude} ],
            'long' => [ $problem->{longitude} ],
            'status' => [ $statusmap{$problem->{state}} ],
            'status_notes' => [ {} ],
            'requested_datetime' => [ $problem->{created} ],
            'updated_datetime' => [ $problem->{lastupdate} ],
            'expected_datetime' => [ {} ],
            'address' => [ {} ],
            'address_id' => [ {} ],
            'service_code' => [ $problem->{category} ],
            'service_name' => [ $problem->{category} ],
            'service_notice' => [ {} ],
            # FIXME create full URL to image
            'media_url' => [ $problem->{has_photo} ? "/photo?id=$id" : {} ],
            'agency_responsible' => [ {} ],
            'zipcode' => [ {} ],
        };
        format_output($q, $format, {'requests' => [{ 'request' => [ $info ]}]});
    } else {
        # FIXME handle bogus IDs
    }
}

sub format_output {
    my ($q, $format, $hashref) = @_;
    if ('json' eq $format) {
        print $q->header( -type => 'application/json; charset=utf-8' );
        print JSON::to_json($hashref);
    } elsif ('xml' eq $format) {
        print $q->header( -type => 'application/xml; charset=utf-8' );
        print XMLout($hashref, RootName => undef);
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
