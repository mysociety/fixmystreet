#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

use_ok( 'Open311::GetUpdates' );
use_ok( 'Open311' );

my $user = FixMyStreet::App->model('DB::User')->find_or_create(
    {
        email => 'system_user@example.com'
    }
);


my $updates = Open311::GetUpdates->new( system_user => $user );
ok $updates, 'created object';

my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
<service_requests>
<request>
<service_request_id>638344</service_request_id>
<status>open</status>
<status_notes>This is a note.</status_notes>
<service_name>Sidewalk and Curb Issues</service_name>
<service_code>006</service_code>
<description></description>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-14T06:37:38-08:00</requested_datetime>
UPDATED_DATETIME
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>37.762221815</lat>
<long>-122.4651145</long>
</request>
</service_requests>
};

my $problem_rs = FixMyStreet::App->model('DB::Problem');
my $problem = $problem_rs->new(
    {
        postcode     => 'EH99 1SP',
        latitude     => 1,
        longitude    => 1,
        areas        => 1,
        title        => '',
        detail       => '',
        used_map     => 1,
        user_id      => 1,
        name         => '',
        state        => 'confirmed',
        service      => '',
        cobrand      => 'default',
        cobrand_data => '',
        user         => $user,
        created      => DateTime->now()->subtract( days => 1 ),
        lastupdate   => DateTime->now()->subtract( days => 1 ),
        anonymous    => 1,
        external_id  => 638344,
    }
);

$problem->insert;

for my $test (
    {
        desc => 'element missing',
        updated_datetime => '',
        comment_count => 0,
    },
    {
        desc => 'empty element',
        updated_datetime => '<updated_datetime />',
        comment_count => 0,
    },
    {
        desc => 'element with no content',
        updated_datetime => '<updated_datetime></updated_datetime>',
        comment_count => 0,
    },
    {
        desc => 'element with old content',
        updated_datetime => sprintf( '<updated_datetime>%s</updated_datetime>', DateTime->now->subtract( days => 3 ) ),
        comment_count => 0,
    },
    {
        desc => 'element with new content',
        updated_datetime => sprintf( '<updated_datetime>%s</updated_datetime>', DateTime->now ),
        comment_count => 1,
    },
) {
    subtest $test->{desc} => sub {
        $problem->comments->delete;
        $problem->lastupdate(DateTime->now()->subtract( days => 1 ) ),
        $problem->update;

        my $local_requests_xml = $requests_xml;
        $local_requests_xml =~ s/UPDATED_DATETIME/$test->{updated_datetime}/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'requests.xml' => $local_requests_xml } );

        ok $updates->update_reports( [ 638344 ], $o, { name => 'Test Council' } );
        is $o->test_uri_used, 'http://example.com/requests.xml?jurisdiction_id=mysociety&service_request_id=638344', 'get url';

        is $problem->comments->count, $test->{comment_count}, 'added a comment';
    };
}

$requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
<service_requests>
<request>
<service_request_id>638344</service_request_id>
<status>open</status>
<status_notes>This is a note.</status_notes>
<service_name>Sidewalk and Curb Issues</service_name>
<service_code>006</service_code>
<description></description>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-14T06:37:38-08:00</requested_datetime>
<updated_datetime>UPDATED_DATETIME</updated_datetime>
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>37.762221815</lat>
<long>-122.4651145</long>
</request>
<request>
<service_request_id>638345</service_request_id>
<status>open</status>
<status_notes>This is a for a different issue.</status_notes>
<service_name>Sidewalk and Curb Issues</service_name>
<service_code>006</service_code>
<description></description>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-14T06:37:38-08:00</requested_datetime>
<updated_datetime>UPDATED_DATETIME2</updated_datetime>
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>37.762221815</lat>
<long>-122.4651145</long>
</request>
</service_requests>
};

my $problem2 = $problem_rs->create(
    {
        postcode     => 'EH99 1SP',
        latitude     => 1,
        longitude    => 1,
        areas        => 1,
        title        => '',
        detail       => '',
        used_map     => 1,
        user_id      => 1,
        name         => '',
        state        => 'confirmed',
        service      => '',
        cobrand      => 'default',
        cobrand_data => '',
        user         => $user,
        created      => DateTime->now()->subtract( days => 1 ),
        lastupdate   => DateTime->now()->subtract( days => 1 ),
        anonymous    => 1,
        external_id  => 638345,
    }
);

$problem->comments->delete;
subtest 'update with two requests' => sub {
    $problem->comments->delete;
    $problem->lastupdate(DateTime->now()->subtract( days => 1 ) ),

    my $date1 = DateTime::Format::W3CDTF->new->format_datetime( DateTime->now() );
    my $date2 = DateTime::Format::W3CDTF->new->format_datetime( DateTime->now->subtract( hours => 1) );
    my $local_requests_xml = $requests_xml;
    $local_requests_xml =~ s/UPDATED_DATETIME2/$date2/;
    $local_requests_xml =~ s/UPDATED_DATETIME/$date1/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'requests.xml' => $local_requests_xml } );

    ok $updates->update_reports( [ 638344,638345 ], $o, { name => 'Test Council' } );
    is $o->test_uri_used, 'http://example.com/requests.xml?jurisdiction_id=mysociety&service_request_id=638344%2C638345', 'get url';

    is $problem->comments->count, 1, 'added a comment to first problem';
    is $problem2->comments->count, 1, 'added a comment to second problem';
};

$problem->comments->delete;
$problem->delete;
$user->comments->delete;
$user->problems->delete;
$user->delete;

done_testing();
