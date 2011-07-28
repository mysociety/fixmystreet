package FixMyStreet::App::Controller::Open311;

use utf8;
use Moose;
use namespace::autoclean;

use JSON;
use XML::Simple;
use URI::Escape;
use mySociety::DBHandle qw(select_all);
use mySociety::Web qw(ent);

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Open311 - Catalyst Controller

=head1 DESCRIPTION

Open311 server API

Open311 server API for Open311 clients

http://open311.org/
http://wiki.open311.org/GeoReport_v2
http://fixmystreet.org.nz/api
http://seeclickfix.com/open311/

Issues with Open311
 * no way to specify which languages are understood by the
   recipients.  some lang=nb,nn setting should be available.
 * not obvious how to handle generic requests (ie without lat/lon
   values).
 * should service IDs be numeric or not?  Spec do not say, and all
   examples I find use numbers.
 * missing way to search for reports near a location using lat/lon
 * report attributes lack title field.
 * missing way to provide updates information for a request
 * should support GeoRSS output as well as json and home made XML

=head1 METHODS

=cut

=head2 index

Displays some summary information for the requests.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    return show_documentation($c);
}

=head2 discovery

http://search.cpan.org/~bobtfish/Catalyst-Manual-5.8007/lib/Catalyst/Manual/Intro.pod#Action_types

=cut

sub discovery_v2 : Regex('^open311(.cgi)?/v2/discovery.(xml|json|html)$') : Args(0) {
    my ( $self, $c ) = @_;
    my $format = $c->req->captures->[1];
    return get_discovery($c, 'xml');
}

sub services_v2 : Regex('^open311(.cgi)?/v2/services.(xml|json|html)$') : Args(0) {
    my ( $self, $c ) = @_;
    my $format = $c->req->captures->[1];
    return get_services($c, $format);
}

sub requests_v2 : Regex('^open311(.cgi)?/v2/requests.(xml|json|html|rss)$') : Args(0) {
    my ( $self, $c ) = @_;
    my $format = $c->req->captures->[1];
    return get_requests($c, $format);
}

sub request_v2 : Regex('^open311(.cgi)?/v2/requests/(\d+).(xml|json|html)$') : Args(0) {
    my ( $self, $c ) = @_;
    my $id = $c->req->captures->[1];
    my $format = $c->req->captures->[2];
    return get_request($c, $id, $format);
}

sub error : Private {
    my ($q, $error) = @_;
    show_documentation($q, "ERROR: $error");
}

sub show_documentation : Private {
    my ($c, $message) = @_;
    my $jurisdiction_id = 'fiksgatami.no';
    my $response;

    $c->res->content_type('text/html; charset=utf-8');

    $response .= CGI::h1(_('Open311 API for the mySociety FixMyStreet server'));
    $response .= CGI::p(sprintf(_('Note: <strong>%s</strong>'), $message))
        if $message;
    $response .= CGI::p(_('At the moment only searching for and looking at reports work.'));
    $response .= CGI::p(_('This API implementation is work in progress and not yet stabilized.  It will change without warnings in the future.'));

    $response .= CGI::li(CGI::a({rel => 'nofollow',
                        href => "http://www.open311.org/"},
                       _('Open311 initiative web page')));
    $response .= CGI::li(CGI::a({rel => 'nofollow',
                        href => 'http://wiki.open311.org/GeoReport_v2'},
                       _('Open311 specification')));

    $response .= CGI::p(sprintf(_('At most %d requests are returned in each query.  The returned requests are ordered by requested_datetime, so to get all requests, do several searches with rolling start_date and end_date.'),
                        mySociety::Config::get('RSS_LIMIT')));

    my $baseurl = $c->cobrand->base_url();

    $response .= CGI::p(_('The following Open311 v2 attributes are returned for each request: service_request_id, description, lat, long, media_url, status, requested_datetime, updated_datetime, service_code and service_name.'));

    $response .= CGI::p(_('In addition, the following attributes that are not part of the Open311 v2 specification are returned: agency_sent_datetime, title (also returned as part of description), interface_used, comment_count, requestor_name (only present if requestor allowed the name to be shown on this site).'));

    $response .= CGI::p(_('The Open311 v2 attribute agency_responsible is used to list the administrations that received the problem report, which is not quite the way the attribute is defined in the Open311 v2 specification.'));

    my $mapiturl = mySociety::Config::get('MAPIT_URL');
    $response .= CGI::p(sprintf(_('With request searches, it is also possible to search for agency_responsible to limit the requests to those sent to a single administration.  The search term is the administration ID provided by <a href="%s">MaPit</a>.'), $mapiturl));

    $response .= CGI::p(_('Examples:'));

    $response .= "<ul>\n";

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
         url => "$baseurl/open311.cgi/v2/services.xml?jurisdiction_id=$jurisdiction_id?lat=11&long=60",
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
            my $encurl = CGI::escape($rssurl);
            $googlemapslink = ' [ ' .
                CGI::a({href => "http://maps.google.com/?q=$encurl"},
                      _('GeoRSS on Google Maps')) . ' ]';
        }
        $response .= CGI::li(CGI::a({href => $url}, $info) . $googlemapslink . '<br>' .
                     ent($url));
    }

    $response .= <<EOF;
</ul>

<h2>Searching</h2>

<p>The following search parameters can be used:</p>

<dl>

<dt>service_request_id</dt>
<dd>Search for numeric ID of specific request.
   Using this is identical to asking for a individual request using
   the /requests/number.format URL.</dd>
<dt>service_code</dt>
<dd>Search for the given category / service type string.</dd>

<dt>status</dt>
<dd>Search for open or closed (fixed) requests.</dd>

<dt>start_date<dt>
<dd>Only return requests with requested_datetime set after or at the
  date and time specified.  The format is YYYY-MM-DDTHH:MM:SS+TZ:TZ.</dd>

<dt>end_date<dt>
<dd>Only return requests with requested_datetime set before the date
  and time specified.  Same format as start_date.</dd>

<dt>agency_responsible</dt>
<dd>ID of government body receiving the request.  Several IDs can be
  specified with | as a separator.</dd>

<dt>interface_used<dt>
<dd>Name / identifier of interface used.</dd>

<dt>has_photo<dt>
<dd>Search for entries with or without photos.  Use value 'true' to
only get requests created with images, and 'false' to get those
created without images.</dd>

<dt>max_requests</dt>
<dd>Max number of requests to return from the search.  If it is larger
than the site specific max_requests value specified in the discovery
call, the value provided is ignored.</dd>

<dl>

<p>The search result might look like this:</p>

EOF

    $response .= xml_format("
  <requests>
    <request>
      <agency_responsible>
        <recipient>Statens vegvesen region øst</recipient>
        <recipient>Oslo</recipient>
      </agency_responsible>
      <agency_sent_datetime>2011-04-23T10:28:55+02:00</agency_sent_datetime>
      <description>Mangler brustein: Det støver veldig på tørre dager.  Her burde det vært brustein.</description>
      <detail>Det støver veldig på tørre dager.  Her burde det vært brustein.</detail>
      <interface_used>Web interface</interface_used>
      <lat>59.916848</lat>
      <long>10.728148</long>
      <requested_datetime>2011-04-23T09:32:36+02:00</requested_datetime>
      <requestor_name>Petter Reinholdtsen</requestor_name>
      <service_code>Annet</service_code>
      <service_name>Annet</service_name>
      <service_request_id>1</service_request_id>
      <status>open</status>
      <title>Mangler brustein</title>
      <updated_datetime>2011-04-23T10:28:55+02:00</updated_datetime>
    </request>
  </requests>
");

    $c->stash->{response} = $response;
}

sub xml_format : Private {
    my $xml = shift;
    return '<pre>' . ent($xml) . '</pre>';
}

# Example
# http://sandbox.georeport.org/tools/discovery/discovery.xml
sub get_discovery : Private {
    my ($c, $format) = @_;
    my $contact_email = mySociety::Config::get('CONTACT_EMAIL');
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
    format_output($c, $format, {'discovery' => $info});
}

# Example
# http://seeclickfix.com/open311/services.html?lat=32.1562864999991&lng=-110.883806
sub get_services : Private {
    my ($c, $format) = @_;
    my $jurisdiction_id = $c->req->param('jurisdiction_id') || '';
    my $lat = $c->req->param('lat') || '';
    my $lon = $c->req->param('long') || '';

    my @area_types = $c->cobrand->area_types;
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
    format_output($c, $format, {'services' => [{ 'service' => \@services}]});
}


sub output_requests : Private {
    my ($c, $format, $criteria, $limit, @args) = @_;
    # Look up categories for this council or councils
    my $query =
        "SELECT id, title, detail, latitude, longitude, state, ".
        "category, created, confirmed, whensent, lastupdate, council, ".
        "service, name, anonymous, ".
        "(photo is not null) as has_photo FROM problem ".
        "WHERE $criteria ORDER BY confirmed desc";

    my $open311limit = mySociety::Config::get('RSS_LIMIT');
    $open311limit = $limit if ($limit && $limit < $open311limit);
    $query .= " LIMIT $open311limit" if $open311limit;

    my $problems = select_all($query, @args);

    my %statusmap = ( 'fixed' => 'closed',
                      'confirmed' => 'open');

    my @problemlist;
    my @councils;
    for my $problem (@{$problems}) {
        my $id = $problem->{id};

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
            'detail'  => [ $problem->{detail} ], # Not in Open311 v2
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
        };

        if ($problem->{anonymous} == 0){
            # Not in Open311 v2
            $request->{'requestor_name'} = [ $problem->{name} ];
        }
        if ( $problem->{whensent} ) {
            # Not in Open311 v2
            $request->{'agency_sent_datetime'} =
                [ w3date($problem->{whensent}) ];
        }
# FIXME Find way to get comment count
#        my $comment_count =
#            dbh()->selectrow_array("select count(*) from comment ".
#                                   "where state='confirmed' and ".
#                                   "problem_id = $id");
#        if ($comment_count) {
#            # Not in Open311 v2
#            $request->{'comment_count'} = [ $comment_count ];
#        }
        # Extract number of comments/updates
        my $updates = $c->model('DB::Comment')->search(
            { problem_id => $id, state => 'confirmed' },
            { order_by => 'confirmed' }
            );
        if ($updates->count()) {
            $request->{'comment_count'} = [ $updates->count() ];
        }

        my $display_photos = $c->cobrand->allow_photo_display;
        if ($display_photos && $problem->{has_photo}) {
            my $url = $c->cobrand->base_url();
            my $imgurl = $url . "/photo?id=$id";
            $request->{'media_url'} = [ $imgurl ];
        }
        push(@problemlist, $request);
    }
    my $areas_info = mySociety::MaPit::call('areas', \@councils);
    foreach my $request (@problemlist) {
        if ($request->{agency_responsible}) {
            my @council_names = map { $areas_info->{$_}->{name} } @{$request->{agency_responsible}} ;
            $request->{agency_responsible} =
                [ {'recipient' => [ @council_names ] } ];
        }
    }
    format_output($c, $format, {'requests' => [{ 'request' => \@problemlist}]});
}

sub get_requests : Private {
    my ($c, $format) = @_;
    return unless is_jurisdiction_id_ok($c);

    my %rules = (
        service_request_id => 'id = ?',
        service_code       => 'category = ?',
        status             => 'state = ?',
        start_date         => 'confirmed >= ?',
        end_date           => 'confirmed < ?',
        agency_responsible => 'council ~ ?',
        interface_used     => 'service is not null and service = ?',
        max_requests       => '',
        has_photo          => '',
        );
    my $max_requests = 0;
    my @args;
    # Only provide access to the published reports
    my $criteria = "state in ('fixed', 'confirmed')";
    for my $param (keys %rules) {
        if ($c->req->param($param)) {
            my @value = ($c->req->param($param));
            my $rule = $rules{$param};
            if ('status' eq $param) {
                $value[0] = {
                    'open' => 'confirmed',
                    'closed' => 'fixed'
                }->{$value[0]};
            } elsif ('agency_responsible' eq $param) {
                my $combined_rule = '';
                my @valuelist;
                for my $agency (split(/\|/, $value[0])) {
                    unless ($agency =~ m/^(\d+)$/) {
                        error ($c,
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
            } elsif ('max_requests' eq $param) {
                $max_requests = $value[0];
                @value = ();
            } elsif ('has_photo' eq $param) {
                if ('true' eq $value[0]) {
                    $criteria .= ' and photo is not null';
                    @value = ();
                } elsif ('false' eq $value[0]) {
                    $criteria .= ' and photo is null';
                    @value = ();
                } else {
                    error($c,
                          sprintf(_('Incorrect has_photo value "%s"'),
                                  $value[0]));
                    return;
                }
            } elsif ('interface_used' eq $param) {
                if ('Web interface' eq $value[0]) {
                    $rule = 'service is null'
                }
            }
            if (@value) {
                $criteria .= " and $rule";
                push(@args, @value);
            }
        }
    }

#    if ('rss' eq $format) {
# FIXME write new implementatin
#        my $cobrand = Page::get_cobrand($c);
#        my $alert_type = 'open311_requests_rss';
#        my $xsl = $c->cobrand->feed_xsl;
#        my $qs = '';
#        my %title_params;
#        my $out =
#            FixMyStreet::Alert::generate_rss('new_problems', $xsl,
#                                             $qs, \@args,
#                                             \%title_params, $cobrand,
#                                             $c, $criteria, $max_requests);
#        print $c->header( -type => 'application/xml; charset=utf-8' );
#        print $out;
#    } else {
        output_requests($c, $format, $criteria, $max_requests, @args);
#    }
}

# Example
# http://seeclickfix.com/open311/requests/1.xml?jurisdiction_id=sfgov.org
sub get_request : Private {
    my ($c, $id, $format) = @_;
    return unless is_jurisdiction_id_ok($c);

    my $criteria = "state IN ('fixed', 'confirmed') AND id = ?";
    if ('html' eq $format) {
        my $base_url = $c->cobrand->base_url();
        print $c->redirect($base_url . "/report/$id");
        return;
    }
    output_requests($c, $format, $criteria, 0, $id);
}

sub format_output : Private {
    my ($c, $format, $hashref) = @_;
    if ('json' eq $format) {
        $c->res->content_type('application/json; charset=utf-8');
        $c->stash->{response} = JSON::to_json($hashref);
    } elsif ('xml' eq $format) {
        $c->res->content_type('application/xml; charset=utf-8');
        $c->stash->{response} = XMLout($hashref, RootName => undef);
    } else {
        error($c, sprintf(_('Invalid format %s specified.'), $format));
        return;
    }
}

sub is_jurisdiction_id_ok : Private {
    my ($c) = @_;
    unless (my $jurisdiction_id = $c->req->param('jurisdiction_id')) {
        error($c, _('Missing jurisdiction_id'));
        return 0;
    }
    return 1;
}

# Input:  2011-04-23 10:28:55.944805<
# Output: 2011-04-23T10:28:55+02:00
# FIXME Need generic solution to find time zone
sub w3date : Private {
    my $datestr = shift;
    if (defined $datestr) {
        $datestr =~ s/ /T/;
        my $tz = '+02:00';
        $datestr =~ s/\.\d+$/$tz/;
    }
    return $datestr;
}

sub end : Private {
    my ( $self, $c ) = @_;

    my $response =
      $c->stash->{error}
      ? { error => $c->stash->{error} }
      : $c->stash->{response};

    $c->res->body( $response || {} );
}

=head1 AUTHOR

Copyright (c) 2011 Petter Reinholdtsen, some rights reserved.
Email: pere@hungry.com

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the  GPL v2 or later.

=cut

__PACKAGE__->meta->make_immutable;

1;
