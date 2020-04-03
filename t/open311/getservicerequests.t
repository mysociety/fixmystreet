#!/usr/bin/env perl

use FixMyStreet::TestMech;

use_ok( 'Open311' );
use_ok( 'Open311::GetServiceRequests' );
use DateTime;
use DateTime::Format::W3CDTF;
use Test::MockObject::Extends;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('system_user@example.com', name => 'test users');
my $body = $mech->create_body_ok(2482, 'Bromley');
my $contact = $mech->create_contact_ok( body_id => $body->id, category => 'Sidewalk and Curb Issues', email => 'sidewalks' );

my $body2 = $mech->create_body_ok(2217, 'Buckinghamshire');
my $contact2 = $mech->create_contact_ok( body_id => $body2->id, category => 'Sidewalk and Curb Issues', email => 'sidewalks' );

my $hounslow = $mech->create_body_ok(2483, 'Hounslow');
my $hounslowcontact = $mech->create_contact_ok( body_id => $hounslow->id, category => 'Sidewalk and Curb Issues', email => 'sidewalks' );

my $dtf = DateTime::Format::W3CDTF->new;

my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
<service_requests>
<request>
<service_request_id>638344</service_request_id>
<status>open</status>
<status_notes>This is a note.</status_notes>
<service_name>Sidewalk and Curb Issues</service_name>
<service_code>sidewalks</service_code>
<description>This is a sidewalk problem</description>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-14T06:37:38-08:00</requested_datetime>
<updated_datetime>2010-04-14T06:37:38-08:00</updated_datetime>
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>51.4021</lat>
<long>0.01578</long>
</request>
<request>
<service_request_id>638345</service_request_id>
<status>investigating</status>
<status_notes>This is a for a different issue.</status_notes>
<service_name>Not Sidewalk and Curb Issues</service_name>
<service_code>not_sidewalks</service_code>
<description>This is a problem</description>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-15T06:37:38-08:00</requested_datetime>
<updated_datetime>2010-04-15T06:37:38-08:00</updated_datetime>
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>51.4021</lat>
<long>0.01578</long>
</request>
<request>
<service_request_id>638346</service_request_id>
<status>open</status>
<status_notes>This is a note.</status_notes>
<service_name>Sidewalk and Curb Issues</service_name>
<service_code>sidewalks</service_code>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-14T06:37:38-08:00</requested_datetime>
<updated_datetime>2010-04-14T06:37:38-08:00</updated_datetime>
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>51.4021</lat>
<long>0.01578</long>
</request>
</service_requests>
};

my $o = Open311->new(
    jurisdiction => 'mysociety',
    endpoint => 'http://example.com',
    test_mode => 1,
    test_get_returns => { 'requests.xml' => $requests_xml }
);

my $p1_date = $dtf->parse_datetime('2010-04-14T06:37:38-08:00')
                ->set_time_zone(FixMyStreet->local_time_zone);
my $p2_date = $dtf->parse_datetime('2010-04-15T06:37:38-08:00')
                ->set_time_zone(FixMyStreet->local_time_zone);
my $start_date = $p1_date->clone;
$start_date->add( hours => -2);
my $end_date = $p2_date->clone;
$end_date->add( hours => 2);


subtest 'basic parsing checks' => sub {
    my $update = Open311::GetServiceRequests->new(
        system_user => $user,
        start_date => $start_date,
        end_date => $end_date
    );
    FixMyStreet::override_config {
        TIME_ZONE => 'Asia/Tokyo',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $update->create_problems( $o, $body );
    };


    my $p = FixMyStreet::DB->resultset('Problem')->search(
                { external_id => 638344 }
            )->first;

    ok $p, 'Found problem';
    is $p->title, 'Sidewalk and Curb Issues problem', 'correct problem title';
    is $p->detail, 'This is a sidewalk problem', 'correct problem description';
    is $p->created, $p1_date, 'Problem has correct creation date';
    is $p->confirmed, $p1_date, 'Problem has correct confirmed date';
    is $p->whensent, $p1_date, 'Problem has whensent set';
    is $p->state, 'confirmed', 'correct problem state';
    is $p->user->id, $user->id, 'user set to system user';
    is $p->category, 'Sidewalk and Curb Issues', 'correct problem category';

    my $p2 = FixMyStreet::DB->resultset('Problem')->search( { external_id => 638345 } )->first;
    ok $p2, 'second problem found';
    ok $p2->whensent, 'second problem marked sent';
    is $p2->state, 'investigating', 'second problem correct state';
    is $p2->category, 'Other', 'category falls back to Other';

    my $p3 = FixMyStreet::DB->resultset('Problem')->search( { external_id => 638346 } )->first;
    ok $p3, 'third problem found';
    ok $p3->whensent, 'third problem marked sent';
    is $p3->state, 'confirmed', 'second problem correct state';
    is $p3->category, 'Sidewalk and Curb Issues', 'correct problem category';
    is $p3->detail, 'Sidewalk and Curb Issues problem', 'problem detail based on category name';
};

subtest 'check problems not re-created' => sub {
    my $update = Open311::GetServiceRequests->new( system_user => $user );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $update->create_problems( $o, $body );
    };

    my $count = FixMyStreet::DB->resultset('Problem')->count;

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $update->create_problems( $o, $body );
    };

    my $after_count = FixMyStreet::DB->resultset('Problem')->count;

    is $count, $after_count, "problems not re-created";
};

for my $test (
  {
      desc => 'problem with no id is not created',
      detail => 'This is a problem with no service_code',
      subs => { id => '', desc => 'This is a problem with service code' },
  },
  {
      desc => 'problem with no lat is not created',
      detail => 'This is a problem with no lat',
      subs => { lat => '', desc => 'This is a problem with no lat' },
  },
  {
      desc => 'problem with no long is not created',
      detail => 'This is a problem with no long',
      subs => { long => '', desc => 'This is a problem with no long' },
  },
  {
      desc => 'problem with bad lat/long is not created',
      detail => 'This is a problem with bad lat/long',
      subs => { lat => '51', long => 0.1, desc => 'This is a problem with bad lat/long' },
  },
) {
    subtest $test->{desc} => sub {
        my $xml = prepare_xml( $test->{subs} );
        my $o = Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
            test_mode => 1,
            test_get_returns => { 'requests.xml' => $xml}
        );

        my $count = FixMyStreet::DB->resultset('Problem')->count;
        my $update = Open311::GetServiceRequests->new( system_user => $user );
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $update->create_problems( $o, $body );
        };
        my $after_count = FixMyStreet::DB->resultset('Problem')->count;

        is $count, $after_count, "problems not created";

        my $with_text = FixMyStreet::DB->resultset('Problem')->search( {
              detail => $test->{detail}
        } )->count;

        is $with_text, 0, 'no matching problem created';
    };
}

my $date = DateTime->new(
    year => 2010,
    month => 4,
    day => 14,
    hour => 6,
    minute => 37
);

for my $test (
  {
      start_date => $date->clone->add(hours => -2),
      end_date => $date->clone->add(hours => -1),
      desc => 'do not process if update time after end_date',
      subs => {},
  },
  {
      start_date => $date->clone->add(hours => 2),
      end_date => $date->clone->add(hours => 4),
      desc => 'do not process if update time before start_date',
      subs => {},
  },
  {
      start_date => $date->clone->add(hours => -2),
      end_date => $date->clone->add(hours => 4),
      desc => 'do not process if update time is bad',
      subs => { update_time => '2010/12/12' },
  },
) {
    subtest $test->{desc} => sub {
        my $xml = prepare_xml( $test->{subs} );
        my $o = Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
            test_mode => 1,
            test_get_returns => { 'requests.xml' => $xml}
        );

        my $update = Open311::GetServiceRequests->new(
            start_date => $test->{start_date},
            end_date => $test->{end_date},
            system_user => $user,
        );
        my $count = FixMyStreet::DB->resultset('Problem')->count;
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $update->create_problems( $o, $body );
        };
        my $after = FixMyStreet::DB->resultset('Problem')->count;

        is $count, $after, 'problem not added';
    };
}

subtest 'check fetch_all body setting ignores date errors' => sub {
    my $xml = prepare_xml({ id => '12345678' });

    $body->update( {
        send_method => 'Open311',
        fetch_problems => 1,
        comment_user_id => $user->id,
        endpoint => 'http://open311.localhost/',
        api_key => 'KEY',
        jurisdiction => 'test',
    } );
    $body->set_extra_metadata( fetch_all_problems => 1 );
    $body->update();

    my $update = Open311::GetServiceRequests->new(
        verbose => 1,
        system_user => $user,
    );
    $update = Test::MockObject::Extends->new($update);

    $update->mock('create_open311_object', sub {
        return Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
            test_mode => 1,
            test_get_returns => { 'requests.xml' => $xml}
        );
    } );

    my $count = FixMyStreet::DB->resultset('Problem')->count;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $update->fetch;
    };

    my $after = FixMyStreet::DB->resultset('Problem')->count;

    is $after, $count + 1, 'problem created';
};

for my $test (
  {
      desc => 'convert easting/northing to lat/long',
      subs => { lat => 168935, long => 540315 },
      expected => { lat => 51.402096, long => 0.015784 },
  },
) {
    subtest $test->{desc} => sub {
        my $xml = prepare_xml( $test->{subs} );
        my $o = Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
            test_mode => 1,
            test_get_returns => { 'requests.xml' => $xml}
        );

        my $update = Open311::GetServiceRequests->new(
            system_user => $user,
            convert_latlong => 1,
            start_date => $start_date,
            end_date => $end_date
        );

        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $update->create_problems( $o, $body );
        };

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 123456 }
        )->first;

        ok $p, 'problem created';
        is $p->latitude, $test->{expected}->{lat}, 'correct latitude';
        is $p->longitude, $test->{expected}->{long}, 'correct longitude';

        $p->delete;
    };
}

subtest "check options passed through from body" => sub {
    my $xml = prepare_xml( {} );

    $body->update( {
        send_method => 'Open311',
        fetch_problems => 1,
        comment_user_id => $user->id,
        endpoint => 'http://open311.localhost/',
        convert_latlong => 1,
        api_key => 'KEY',
        jurisdiction => 'test',
    } );

    my $o = Open311::GetServiceRequests->new();

    my $props = {};

    $o = Test::MockObject::Extends->new($o);
    $o->mock('create_problems', sub {
        my $self = shift;

        $props->{convert_latlong} = $self->convert_latlong;
    } );

    $o->fetch();

    ok $props->{convert_latlong}, "convert latlong set"
};

my $non_public_xml = qq[<?xml version="1.0" encoding="utf-8"?>
<service_requests>
<request>
<service_request_id>123456</service_request_id>
<status>open</status>
<status_notes></status_notes>
<service_name>Sidewalk and Curb Issues</service_name>
<service_code>sidewalks</service_code>
<description>this is a problem</description>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-14T06:37:38-08:00</requested_datetime>
<updated_datetime>2010-04-14T06:37:38-08:00</updated_datetime>
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>51.4021</lat>
<long>0.01578</long>
<non_public>1</non_public>
</request>
</service_requests>
];

for my $test (
  {
      desc => 'non public is set',
      non_public => 1,
  },
  {
      desc => 'non public is not set',
      non_public => 0,
  },
) {
    subtest $test->{desc} => sub {
        (my $xml = $non_public_xml) =~ s/non_public>1/non_public>$test->{non_public}/;

        my $o = Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
            test_mode => 1,
            test_get_returns => { 'requests.xml' => $xml}
        );

        my $update = Open311::GetServiceRequests->new(
            system_user => $user,
            start_date => $start_date,
            end_date => $end_date
        );

        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $update->create_problems( $o, $body );
        };

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 123456 }
        )->first;

        ok $p, 'problem created';
        is $p->non_public, $test->{non_public}, "report non_public is set correctly";

        $p->delete;
    };
}

my $hounslow_non_public_xml = qq[<?xml version="1.0" encoding="utf-8"?>
<service_requests>
<request>
<service_request_id>123456</service_request_id>
<status>open</status>
<status_notes></status_notes>
<service_name>Sidewalk and Curb Issues</service_name>
<service_code>sidewalks</service_code>
<description>this is a problem</description>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-14T06:37:38-08:00</requested_datetime>
<updated_datetime>2010-04-14T06:37:38-08:00</updated_datetime>
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>51.482286</lat>
<long>-0.328163</long>
<non_public>1</non_public>
</request>
</service_requests>
];

for my $test (
  {
      desc => 'Hounslow non_public reports not created',
      non_public => 1,
      count => 0,
  },
  {
      desc => 'Hounslow public reports are created',
      non_public => 0,
      count => 1,
  },
) {
    subtest $test->{desc} => sub {
        (my $xml = $hounslow_non_public_xml) =~ s/non_public>1/non_public>$test->{non_public}/;

        my $o = Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
            test_mode => 1,
            test_get_returns => { 'requests.xml' => $xml}
        );

        my $update = Open311::GetServiceRequests->new(
            system_user => $user,
            start_date => $start_date,
            end_date => $end_date
        );

        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
            ALLOWED_COBRANDS => [ 'hounslow' ],
        }, sub {
            $update->create_problems( $o, $hounslow );
        };

        my $q = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 123456 }
        );

        is $q->count, $test->{count}, 'problem count is correct';

        $q->first->delete if $test->{count};
    };
}

subtest "non_public contacts result in non_public reports" => sub {

    $contact->update({
        non_public => 1
    });
    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'requests.xml' => prepare_xml( {} ) }
    );

    my $update = Open311::GetServiceRequests->new(
        system_user => $user,
        start_date => $start_date,
        end_date => $end_date
    );

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $update->create_problems( $o, $body );
    };

    my $p = FixMyStreet::DB->resultset('Problem')->search(
        { external_id => 123456 }
    )->first;

    ok $p, 'problem created';
    is $p->non_public, 1, "report non_public is set correctly";

    $p->delete;
    $contact->update({
        non_public => 0
    });

};

for my $test (
  {
      test_desc => 'filters out phone numbers',
      desc => 'This has a description with values:0117 469 0123 and more 07700 900123',
  },
  {
      test_desc => 'filters out emails',
      desc => 'This has a description with values:test@example.org and more user@council.gov.uk',
  },
) {
    subtest $test->{test_desc} => sub {
        my $xml = prepare_xml({
            desc => $test->{desc},
            lat => 51.615559,
            long => -0.556903,
        });

        my $o = Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
            test_mode => 1,
            test_get_returns => { 'requests.xml' => $xml}
        );

        my $update = Open311::GetServiceRequests->new(
            system_user => $user,
            start_date => $start_date,
            end_date => $end_date
        );

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'FixMyStreet', 'Buckinghamshire' ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $update->create_problems( $o, $body2 );
        };

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 123456 }
        )->first;

        ok $p, 'problem created';
        is $p->detail, 'This has a description with values: and more ', "report description filtered";

        $p->delete;
    };
}

sub prepare_xml {
    my $replacements = shift;

    my %defaults = (
        desc => 'this is a problem',
        lat => 51.4021,
        long => 0.01578,
        id => 123456,
        update_time => '2010-04-14T06:37:38-08:00',
        %$replacements
    );

    my $xml = qq[<?xml version="1.0" encoding="utf-8"?>
<service_requests>
<request>
<service_request_id>XXX_ID</service_request_id>
<status>open</status>
<status_notes></status_notes>
<service_name>Sidewalk and Curb Issues</service_name>
<service_code>sidewalks</service_code>
<description>XXX_DESC</description>
<agency_responsible></agency_responsible>
<service_notice></service_notice>
<requested_datetime>2010-04-14T06:37:38-08:00</requested_datetime>
<updated_datetime>XXX_UPDATE_TIME</updated_datetime>
<expected_datetime>2010-04-15T06:37:38-08:00</expected_datetime>
<lat>XXX_LAT</lat>
<long>XXX_LONG</long>
</request>
</service_requests>
];

    for my $key (keys %defaults) {
        my $string = 'XXX_' . uc $key;
        $xml =~ s/$string/$defaults{$key}/;
    }

    return $xml;
}

done_testing();
