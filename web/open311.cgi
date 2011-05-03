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
#  * should support GeoRSS output as well as json and home made XML

use strict;
use warnings;

use Standard;

use JSON;
use XML::Simple;
use URI::Escape;
use Page;
use Problems;
use FixMyStreet::Alert;
use mySociety::DBHandle qw(select_all);
use mySociety::Web qw(ent);

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
    } elsif ($path_info =~ m%^/v2/requests.(xml|json|html|rss)$%) {
        my ($format) = ($1);
        return get_requests($q, $format);
    } else {
        return show_documentation($q);
    }
}
Page::do_fastcgi(\&main);

sub error {
    my ($q, $error) = @_;
    show_documentation($q, "ERROR: $error");
}

sub show_documentation {
    my ($q, $message) = @_;
    my $jurisdiction_id = 'fiksgatami.no';

    print $q->header(-charset => 'utf-8', -content_type => 'text/html');
    print $q->p(_('Open311 API for the mySociety FixMyStreet server'));
    print $q->p(sprintf(_('Note: <strong>%s</strong>', $message)))
        if $message;
    print $q->p(_('At the moment only searching for and looking at reports work.'));
    print $q->p(_('This API implementation is work in progress and not yet stabilized.  It will change without warnings in the future.'));

    print $q->li($q->a({rel => 'nofollow',
                        href => "http://www.open311.org/"},
                       _('Open311 initiative web page')));
    print $q->li($q->a({rel => 'nofollow',
                        href => 'http://wiki.open311.org/GeoReport_v2'},
                       _('Open311 specification')));

    print $q->p(sprintf(_('At most %d requests are returned in each query.  The returned requests are ordered by updated_datetime, so to get all requests, do several searches with rolling start_date and end_date.'),
                        mySociety::Config::get('RSS_LIMIT')));

    my $cobrand = Page::get_cobrand($q);
    my $url = Cobrand::base_url($cobrand);
    my $baseurl = Cobrand::url($cobrand, $url, $q);

    print <<EOF;

<p>The following Open311 v2 attributes are returned for each request:
service_request_id, description, lat, long, media_url, status,
requested_datetime, updated_datetime, service_code and
service_name.</p>

<p>In addition, the following attributes that are not part of the
Open311 v2 specification are returned: agency_sent_datetime, title
(also returned as part of description), interface_used, comment_count,
citicen_anonymous and citicen_name (if citicen_anonymous is not
true).</p>

<p>The Open311 v2 attribute agency_responsible is used to list the
administrations that received the problem report, which is not quite
the way the attribute is defined in the Open311 v2 specification.</p>

<p>With request searches, it is also possible to search for
agency_responsible to limit the requests to those sent to a single
administration.  The search term is the administration ID provided by
<a href="http://mapit.nuug.no/">MaPit</a>.</p>

<p>Examples:</p>

<ul>
EOF
n
    my @examples =
    (
     {
         url => "$baseurl/open311.cgi/v2/discovery.xml?jurisdiction_id=$jurisdiction_id",
         info => 'discovery information',
     },
     {
         url => "$baseurl/open311.cgi/v2/services.xml?jurisdiction_id=$jurisdiction_id",
         info => 'list of services provided',
     },
     {
         url => "$baseurl/open311.cgi/v2/services.xml?jurisdiction_id=$jurisdiction_id?lat=11&lng=60",
         info => 'list of services provided for WGS84 coordinate latitude 11 longitude 60',
     },
     {
         url => "$baseurl/open311.cgi/v2/requests/1.xml?jurisdiction_id=$jurisdiction_id",
         info => 'Request number 1',
     },
     {
         url => "$baseurl/open311.cgi/v2/requests.xml?jurisdiction_id=$jurisdiction_id&status=open&agency_responsible=1601&end_date=2011-03-10",
         info => 'All open requests reported before 2011-03-10 to Trondheim (id 1601)',
     },
     {
         url => "$baseurl/open311.cgi/v2/requests.xml?jurisdiction_id=$jurisdiction_id&status=open&agency_responsible=219|220",
         info => 'All open requests in Asker (id 220) and Bærum (id 219)',
     },
     {
         url => "$baseurl/open311.cgi/v2/requests.xml?jurisdiction_id=$jurisdiction_id&service_code=Vannforsyning",
         info => "All requests with the category 'Vannforsyning'",
     },
     {
         url => "$baseurl/open311.cgi/v2/requests.xml?jurisdiction_id=$jurisdiction_id&status=closed",
         info => 'All closed requests',
     },
    );
    for my $example (@examples) {
        my $url = $example->{url};
        my $info = $example->{info};
        my $googlemapslink = '';
        if ($url =~ m%/requests.xml%) {
            my $rssurl = $url;
            $rssurl =~ s/.xml/.rss/;
            my $encurl = $q->escape($rssurl);
            $googlemapslink = '<br>' .
                $q->a({href => "http://maps.google.com/?q=$encurl"},
                      _('GeoRSS on Google Maps'));
        }
        print $q->li($q->a({href => $url}, $info) . '<br>' .
                     ent($url) .
                     $googlemapslink);
    }

    print <<EOF;
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
        'max_requests' => [ mySociety::Config::get('RSS_LIMIT') ],
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
    my $lon = $q->param('lng') || '';

    my $cobrand = Page::get_cobrand($q);
    my @area_types = Cobrand::area_types($cobrand);

    my $criteria;
    if ($lat || $lon) {
        my $all_councils = mySociety::MaPit::call('point',
                                                  "4326/$lon,$lat",
                                                  type => \@area_types);
        $criteria = 'and area_id IN (' . join(',', keys %$all_councils) . ')';
    } else {
        $criteria = '';
    }

    # Look up categories for this council or councils
    my $categories =
        select_all('SELECT DISTINCT category FROM contacts '.
                   "WHERE deleted='f'" . $criteria);
    my @services;
    for my $categoryref ( sort {$a->{category} cmp $b->{category} }
                          @$categories) {
        my $categoryname = $categoryref->{category};
        push(@services,
             {
                 # FIXME Open311 v2 seem to require all three, and we
                 # only have one value.
                 'service_name' => [ $categoryname ],
                 'description' =>  [ $categoryname ],
                 'service_code' => [ $categoryname ],
                 'metadata' => [ 'false' ],
                 'type' => [ 'realtime' ],
#                 'group' => [ '' ],
#                 'keywords' => [ '' ],
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
        "WHERE $criteria ORDER BY confirmed desc";

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
            'requested_datetime' => [ w3date($problem->{confirmed}) ],
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
        my $comment_count =
            dbh()->selectrow_array("select count(*) from comment ".
                                   "where state='confirmed' and ".
                                   "problem_id = $id");
        if ($comment_count) {
            # Not in Open311 v2
            $request->{'comment_count'} = [ $comment_count ];
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
    unless (my $jurisdiction_id = $q->param('jurisdiction_id')) {
        error($q, _('Missing jurisdiction_id'));
        return;
    }

    my %rules = (
        service_request_id => 'id = ?',
        service_code       => 'category = ?',
        status             => 'state = ?',
        start_date         => "date_trunc('day',confirmed) >= ?",
        end_date           => "date_trunc('day',confirmed) <= ?",
        agency_responsible => "council ~ ?",
        interface_used     => 'service is not null and service = ?',
        );
    my @args;
    # Only provide access to the published reports
    my $criteria = "state in ('fixed', 'confirmed')";
    for my $param (keys %rules) {
        if ($q->param($param)) {
            my @value = ($q->param($param));
            my $rule = $rules{$param};
            if ('status' eq $param) {
                $value[0] = {
                    'open' => 'confirmed',
                    'closed' => 'fixed'
                }->{$value[0]};
            } elsif ('start_date' eq $param || 'end_date' eq $param) {
                if ($value[0] !~ /^\d{4}-\d\d-\d\d$/) {
                    error($q, _('Invalid dates supplied'));
                    return;
                }
            } elsif ('agency_responsible' eq $param) {
                my $combined_rule = '';
                my @valuelist;
                for my $agency (split(/\|/, $value[0])) {
                    unless ($agency =~ m/^(\d+)$/) {
                        error ($q,
                               sprintf(_('Invalid agency_responsible value %s'),
                                       $value[0]));
                        return;
                    }
                    my $agencyid = $1;
                    # FIXME This seem to match the wrong entries
                    # some times.  Not sure when or why
                    my $re = "(\\y$agencyid\\y|^$agencyid\\y|\\y$agencyid\$)";
                    if ($combined_rule) {
                        $combined_rule .= " or $rule";
                    } else {
                        $combined_rule = $rule;
                    }
                    push(@valuelist, $re);
                }
                $rule = "( $combined_rule )";
                @value = @valuelist;
            } elsif ('interface_used' eq $param) {
                if ('Web interface' eq $value[0]) {
                    $rule = 'service is null'
                }
            }
            $criteria .= " and $rule";
            push(@args, @value);
        }
    }

    if ('rss' eq $format) {
        my $cobrand = Page::get_cobrand($q);
        my $alert_type = 'open311_requests_rss';
        my $xsl = Cobrand::feed_xsl($cobrand);
        my $qs = '';
        my %title_params;
        my $out =
            FixMyStreet::Alert::generate_rss('new_problems', $xsl,
                                             $qs, \@args,
                                             \%title_params, $cobrand,
                                             $q, $criteria);
        print $q->header( -type => 'application/xml; charset=utf-8' );
        print $out;
    } else {
        output_requests($q, $format, $criteria, @args);
    }
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
        error($q, sprintf(_('Invalid format %s specified.'), $format));
        return;
    }
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
