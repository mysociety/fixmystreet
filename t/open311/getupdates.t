use utf8;
use FixMyStreet::Test;
use URI::Split qw(uri_split);

use FixMyStreet;
use FixMyStreet::DB;

use_ok( 'Open311::GetUpdates' );
use_ok( 'Open311' );

my $user = FixMyStreet::DB->resultset('User')->find_or_create(
    {
        email => 'system_user@example.com'
    }
);

my $body = FixMyStreet::DB->resultset('Body')->new( {
    name => 'Test Body',
} );

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

my $problem_rs = FixMyStreet::DB->resultset('Problem');
my $problem = $problem_rs->new(
    {
        postcode     => 'EH99 1SP',
        latitude     => 1,
        longitude    => 1,
        areas        => 1,
        title        => '',
        detail       => '',
        used_map     => 1,
        name         => '',
        state        => 'confirmed',
        cobrand      => 'default',
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

        ok $updates->update_reports( [ 638344 ], $o, $body ), 'Updated reports';
        my @parts = uri_split($o->test_uri_used);
        is $parts[2], '/requests.xml', 'path matches';
        my @qs = sort split '&', $parts[3];
        is_deeply(\@qs, [ 'jurisdiction_id=mysociety', 'service_request_id=638344' ], 'query string matches');

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
        name         => '',
        state        => 'confirmed',
        cobrand      => 'default',
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

    ok $updates->update_reports( [ 638344,638345 ], $o, $body ), 'Updated reports';
    my @parts = uri_split($o->test_uri_used);
    is $parts[2], '/requests.xml', 'path matches';
    my @qs = sort split '&', $parts[3];
    is_deeply(\@qs, [ 'jurisdiction_id=mysociety', 'service_request_id=638344%2C638345' ], 'query string matches');

    is $problem->comments->count, 1, 'added a comment to first problem';
    is $problem2->comments->count, 1, 'added a comment to second problem';
};

# No status_notes field now, so that static string in code is used.
$requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
<service_requests>
<request>
<service_request_id>638346</service_request_id>
<status>closed</status>
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

my $problem3 = $problem_rs->create( {
    postcode     => 'EH99 1SP',
    latitude     => 1,
    longitude    => 1,
    areas        => 1,
    title        => 'Title',
    detail       => 'Details',
    used_map     => 1,
    name         => '',
    state        => 'confirmed',
    cobrand      => 'fixamingata',
    user         => $user,
    created      => DateTime->now()->subtract( days => 1 ),
    lastupdate   => DateTime->now()->subtract( days => 1 ),
    anonymous    => 1,
    external_id  => 638346,
} );

subtest 'test translation of auto-added comment from old-style Open311 update' => sub {
    my $dt = sprintf( '<updated_datetime>%s</updated_datetime>', DateTime->now );
    $requests_xml =~ s/UPDATED_DATETIME/$dt/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'requests.xml' => $requests_xml } );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixamingata' ],
    }, sub {
        ok $updates->update_reports( [ 638346 ], $o, $body ), 'Updated reports';
    };
    my @parts = uri_split($o->test_uri_used);
    is $parts[2], '/requests.xml', 'path matches';
    my @qs = sort split '&', $parts[3];
    is_deeply(\@qs, [ 'jurisdiction_id=mysociety', 'service_request_id=638346' ], 'query string matches');

    is $problem3->comments->count, 1, 'added a comment';
    is $problem3->comments->first->text, "Stängd av kommunen", 'correct comment text';
};

END {
    if ($user) {
        $user->comments->delete;
        $user->problems->delete;
        $user->delete;
    }
    done_testing();
}
