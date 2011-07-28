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
    # don't need to do anything here - should just pass through.
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
    my ($c, $error) = @_;
    $c->stash->{error} = "ERROR: $error";
    $c->stash->{template} = 'open311/index.html';
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
    $c->forward( 'is_jurisdiction_id_ok' );

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
                        $c->detach( 'error', [
                               sprintf(_('Invalid agency_responsible value %s'),
                                       $value[0])
                        ] );
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
                    $c->detach( 'error', [
                          sprintf(_('Incorrect has_photo value "%s"'),
                                  $value[0])
                    ] );
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
    $c->forward( 'is_jurisdiction_id_ok' );

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
        $c->detach( 'error', [
            sprintf(_('Invalid format %s specified.'), $format)
        ] );
    }
}

sub is_jurisdiction_id_ok : Private {
    my ( $self, $c ) = @_;
    unless (my $jurisdiction_id = $c->req->param('jurisdiction_id')) {
        $c->detach( 'error', [ _('Missing jurisdiction_id') ] );
    }
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

=head1 AUTHOR

Copyright (c) 2011 Petter Reinholdtsen, some rights reserved.
Email: pere@hungry.com

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the  GPL v2 or later.

=cut

__PACKAGE__->meta->make_immutable;

1;
