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
#    examples I find use numbers.
#  * missing way to search for reports near a location using lat/lon
#  * report attributes lack title field.
#  * missing way to provide updates information for a request

use strict;
use warnings;

use Standard;

use JSON;
use XML::Simple;
use URI::Escape;
use Page;
use Problems;
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
    } elsif ($path_info =~ m%^/v2/requests.(xml|json|html)$%) {
        my ($format) = ($1);
        return get_requests($q, $format);
    } else {
        return show_documentation($q);
    }
}
Page::do_fastcgi(\&main);

sub show_documentation {
    my $q = shift;

    print $q->header(-charset => 'utf-8', -content_type => 'text/html');
    print $q->p(_('Open311 API for FixMyStreet'));
    print $q->p(_('At the moment only searching for and looking at reports work.'));

    print $q->li($q->a({rel => 'nofollow',
                        href => "http://www.open311.org/"},
                       _('Open311 initiative web page')));
    print $q->li($q->a({rel => 'nofollow',
                        href => 'http://wiki.open311.org/GeoReport_v2'},
                       _('Open311 specification')));

    print $q->p(sprintf(_('At most %d requests are returned in each query.  The returned requests are ordered by updated_datetime, so to get all requests, do several searches with rolling start_date and end_date.'),
                        mySociety::Config::get('RSS_LIMIT')));
    print <<EOF;

<p>The following Open311 v2 attributes are returned for each request:
service_request_id, description, lat, long, media_url, status,
requested_datetime, updated_datetime, service_code and
service_name.</p>

<p>In addition, the following attributes that are not part of the
Open311 v2 specification are returned: agency_sent_datetime, title
(also returned as part of description), interface_used and
citicen_anonymous, citicen_name (if citicen_anonymous is not
true).</p>

<p>The Open311 v2 attribute agency_responsible is used to list the
administrations that received the problem report, which is not quite
as the attribute is defined in the Open311 v2 specification.</p>

<p>With request searches, it is also possible to search for
agency_responsible to limit the requests to those sent to a single
administration.  The search term is the administration ID provided by
<a href="http://mapit.nuug.no/">MaPit</a>.</p>

<p>Examples:</p>

<ul>
<li><a href="/open311.cgi/v2/requests/1.xml?jurisdiction_id=dummy">request 1</a></li>
<li><a href="/open311.cgi/v2/requests.xml?jurisdiction_id=dummy&status=open&agency_responsible=1601&end_date=2011-03-10">All open requests reported before 2011-03-10 to Trondheim (id 1601)</a></li>
</ul>

EOF

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
                 'description' =>  [ 'n/a' ], # FIXME required by Open311 v2!
                 'service_code' => [ $categoryname ],
                 'metadata' => [ 'false' ],
                 'type' => [ 'realtime' ],
                 'group' => [ '' ],
                 'keywords' => [ '' ],
             }
            );
    }
    format_output($q, $format, {'services' => [{ 'service' => \@services}]});
}


sub output_requests {
    my ($q, $format, $criteria, @args) = @_;
    # Look up categories for this council or councils
    my $query =
        "SELECT id, title, detail, latitude, longitude, state, ".
        "category, created, whensent, lastupdate, council, service, ".
        "name, anonymous, ".
        "(photo is not null) as has_photo FROM problem ".
        "WHERE $criteria ORDER BY lastupdate";

    my $open311limit = mySociety::Config::get('RSS_LIMIT');
    $query .= " LIMIT $open311limit" if $open311limit;

    my $problems = select_all($query, @args);

    my %statusmap = ( 'fixed' => 'closed',
                      'confirmed' => 'open');

    my @problemlist;
    my @councils;
    for my $problem (@{$problems}) {
        my $id = $problem->{id};

        if ($problem->{anonymous} == 1){
            $problem->{name} = '';
        }
        if ($problem->{service} eq ''){
            $problem->{service} = 'Web interface';
        }
        if ($problem->{council}) {
            $problem->{council} =~ s/\|.*//g;
            my @council_ids = split(/,/, $problem->{council});
            push(@councils, @council_ids);
            $problem->{council} = \@council_ids;
        }

        $problem->{status} = $statusmap{$problem->{state}};

        my $request =
        {
            'service_request_id' => [ $id ],
            'title' => [ $problem->{title} ], # Not in Open311 v2
            'description' => [ $problem->{title} .': ' . $problem->{detail} ],
            'lat' => [ $problem->{latitude} ],
            'long' => [ $problem->{longitude} ],
            'status' => [ $problem->{status} ],
#            'status_notes' => [ {} ],
            'requested_datetime' => [ w3date($problem->{created}) ],
            'updated_datetime' => [ w3date($problem->{lastupdate}) ],
#            'expected_datetime' => [ {} ],
#            'address' => [ {} ],
#            'address_id' => [ {} ],
            'service_code' => [ $problem->{category} ],
            'service_name' => [ $problem->{category} ],
#            'service_notice' => [ {} ],
            'agency_responsible' =>  $problem->{council} , # FIXME Not according to Open311 v2
#            'zipcode' => [ {} ],
            'interface_used' => [ $problem->{service} ], # Not in Open311 v2
            'citicen_anonymous' => [ $problem->{anonymouns} ], # Not in Open311 v2
        };
        if ($problem->{name}) {
            # Not in Open311 v2
            $request->{'citicen_name'} = [ $problem->{name} ];
        }
        if ( $problem->{whensent} ) {
            # Not in Open311 v2
            $request->{'agency_sent_datetime'} =
                [ w3date($problem->{whensent}) ];
        }
        my $cobrand = Page::get_cobrand($q);
        my $url = Cobrand::base_url($cobrand);
        my $display_photos = Cobrand::allow_photo_display($cobrand);
        if ($display_photos && $problem->{has_photo}) {
            my $imgurl = Cobrand::url($cobrand, $url, $q) . "/photo?id=$id";
            $request->{'media_url'} = [ $imgurl ];
        }
        push(@problemlist, $request);
    }
    my $areas_info = mySociety::MaPit::call('areas', \@councils);
    foreach my $request (@problemlist) {
        if ($request->{agency_responsible}) {
            my @council_names = map { $areas_info->{$_}->{name} } @{$request->{agency_responsible}} ;
            $request->{agency_responsible} =
                [ '<recipient>' .
                  join('</recipient><recipient>', @council_names) .
                  '</recipient>'
                ];
        }
    }
    format_output($q, $format, {'requests' => [{ 'request' => \@problemlist}]});
}

sub get_requests {
    my ($q, $format) = @_;
    my $jurisdiction_id    = $q->param('jurisdiction_id') || error();

    my %rules = (
        service_request_id => 'id = ?',
        service_code       => 'category = ?',
        status             => 'state = ?',
        start_date         => "date_trunc('day',lastupdate) >= ?",
        end_date           => "date_trunc('day',lastupdate) <= ?",
        agency_responsible => "council ~ ?",
        );
    my @args;
    # Only provide access to the published reports
    my $criteria = "state in ('fixed', 'confirmed')";
    for my $param (keys %rules) {
        if ($q->param($param)) {
            my $value = $q->param($param);
            my $rule = $rules{$param};
            $criteria .= " and $rule";
            if ('status' eq $param) {
                $value = {
                    'open' => 'confirmed',
                    'closed' => 'fixed'
                }->{$value};
            } elsif ('start_date' eq $param || 'end_date' eq $param) {
                if ($value !~ /^\d{4}-\d\d-\d\d$/) {
                    error('Invalid dates supplied');
                }
            } elsif ('agency_responsible' eq $param) {
                # FIXME This seem to match the wrong entries some
                # times.  Not sure when or why
                $value = "(\\y$value\\y|^$value\\y|\\y$value\$)";
            }
            push(@args, $value);
        }
    }
    output_requests($q, $format, $criteria, @args);
}

# Example
# http://seeclickfix.com/open311/requests/1.xml?jurisdiction_id=sfgov.org
sub get_request {
    my ($q, $id, $format) = @_;
    my $criteria = "state IN ('fixed', 'confirmed') AND id = ?";
    output_requests($q, $format, $criteria, $id);
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

# Input:  2011-04-23 10:28:55.944805<
# Output: 2011-04-23T10:28:55+02:00
# FIXME Need generic solution to find time zone
sub w3date {
    my $datestr = shift;
    $datestr =~ s/ /T/;
    my $tz = '+02:00';
    $datestr =~ s/\.\d+$/$tz/;
    return $datestr;
}
