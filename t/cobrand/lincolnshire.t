use FixMyStreet::TestMech;
use Open311::GetServiceRequests;
use FixMyStreet::DB;
use Open311;

my $mech = FixMyStreet::TestMech->new;

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};
my $body = $mech->create_body_ok(2232, 'Lincolnshire County Council', $params, { cobrand => 'lincolnshire' });
my $lincs_user = $mech->create_user_ok('lincs@example.org', name => 'Lincolnshire User', from_body => $body);
my $superuser = $mech->create_user_ok('super@example.org', name => 'Super User', is_superuser => 1, email_verified => 1);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'lincolnshire',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_SITE => 0,
}, sub {
    subtest "custom homepage text" => sub {
        $mech->get_ok('/');
        $mech->content_contains('like potholes, broken paving slabs, or street lighting');
    };

    subtest "fetching problems from Open311 includes user information" => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="UTF-8"?>
            <service_requests>
                <request>
                    <service_request_id>lincs-123</service_request_id>
                    <status>open</status>
                    <service_name>Street light not working</service_name>
                    <description>Street light not working</description>
                    <requested_datetime>DATETIME</requested_datetime>
                    <updated_datetime>DATETIME</updated_datetime>
                    <address>1 Street</address>
                    <lat>52.656144</lat>
                    <long>-0.502566</long>
                    <contact_name>John Smith</contact_name>
                    <contact_email>john.smith\@example.co.uk</contact_email>
                </request>
            </service_requests>
        };

        my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
        $requests_xml =~ s/DATETIME/$dt/gm;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
        Open311->_inject_response('/requests.xml', $requests_xml);

        my $update = Open311::GetServiceRequests->new(
            system_user => $lincs_user,
        );

        $update->create_problems( $o, $body );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-123' },
            { prefetch => 'user' },
        )->first;

        ok $p, 'Found problem';
        is $p->name, 'John Smith', 'Name set on problem';
        is $p->user->name, 'John Smith', 'correct user associated with problem';
        is $p->user->email, 'john.smith@example.co.uk', 'correct email associated with problem';

        $mech->get_ok("/report/" . $p->id, 'Problem page loaded');
        $mech->content_lacks('John Smith', 'Name not shown on problem page');

        $p->delete;
        FixMyStreet::DB->resultset('User')->search({ email => 'john.smith@example.co.uk' })->delete;
    };

    subtest "ignores user information if name is missing" => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="UTF-8"?>
            <service_requests>
                <request>
                    <service_request_id>lincs-456</service_request_id>
                    <status>open</status>
                    <service_name>Street light not working</service_name>
                    <description>Street light not working</description>
                    <requested_datetime>DATETIME</requested_datetime>
                    <updated_datetime>DATETIME</updated_datetime>
                    <address>1 Street</address>
                    <lat>52.656144</lat>
                    <long>-0.502566</long>
                    <contact_email>john.smith\@example.co.uk</contact_email>
                </request>
            </service_requests>
        };

        my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
        $requests_xml =~ s/DATETIME/$dt/gm;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
        Open311->_inject_response('/requests.xml', $requests_xml);

        my $update = Open311::GetServiceRequests->new(
            system_user => $lincs_user,
        );

        $update->create_problems( $o, $body );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-456' },
            { prefetch => 'user' },
        )->first;

        ok $p, 'Found problem';
        is $p->name, $lincs_user->name, 'Name set on problem';
        is $p->user->name, $lincs_user->name, 'correct user associated with problem';
        is $p->user->email, $lincs_user->email, 'correct email associated with problem';

        $p->delete;
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'lincolnshire',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_SITE => 1,
}, sub {
    subtest "fetching problems from Open311 on staging doesn't include private user information" => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="UTF-8"?>
            <service_requests>
                <request>
                    <service_request_id>lincs-123</service_request_id>
                    <status>open</status>
                    <service_name>Street light not working</service_name>
                    <description>Street light not working</description>
                    <requested_datetime>DATETIME</requested_datetime>
                    <updated_datetime>DATETIME</updated_datetime>
                    <address>1 Street</address>
                    <lat>52.656144</lat>
                    <long>-0.502566</long>
                    <contact_name>John Smith</contact_name>
                    <contact_email>john.smith\@example.co.uk</contact_email>
                </request>
            </service_requests>
        };

        my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
        $requests_xml =~ s/DATETIME/$dt/gm;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
        Open311->_inject_response('/requests.xml', $requests_xml);

        my $update = Open311::GetServiceRequests->new(
            system_user => $lincs_user,
        );

        $update->create_problems( $o, $body );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-123' },
            { prefetch => 'user' },
        )->first;

        ok $p, 'Found problem';
        is $p->name, $lincs_user->name, 'Name set on problem';
        is $p->user->name, $lincs_user->name, 'correct user associated with problem';
        is $p->user->email, $lincs_user->email, 'correct email associated with problem';

        is(FixMyStreet::DB->resultset('User')->search({ email => 'john.smith@example.co.uk' })->count, 0, "User wasn't created");

        $p->delete;
    };

    subtest 'fetching problems from Open311 on staging stores user info for @lincolnshire.gov.uk addresses' => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="UTF-8"?>
            <service_requests>
                <request>
                    <service_request_id>lincs-123</service_request_id>
                    <status>open</status>
                    <service_name>Street light not working</service_name>
                    <description>Street light not working</description>
                    <requested_datetime>DATETIME</requested_datetime>
                    <updated_datetime>DATETIME</updated_datetime>
                    <address>1 Street</address>
                    <lat>52.656144</lat>
                    <long>-0.502566</long>
                    <contact_name>Simon Neil</contact_name>
                    <contact_email>simon.neil\@lincolnshire.gov.uk</contact_email>
                </request>
            </service_requests>
        };

        my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
        $requests_xml =~ s/DATETIME/$dt/gm;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
        Open311->_inject_response('/requests.xml', $requests_xml);

        my $update = Open311::GetServiceRequests->new(
            system_user => $lincs_user,
        );

        $update->create_problems( $o, $body );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-123' },
            { prefetch => 'user' },
        )->first;

        ok $p, 'Found problem';
        is $p->name, "Simon Neil", 'Name set on problem';
        is $p->user->name, "Simon Neil", 'correct user associated with problem';
        is $p->user->email, 'simon.neil@lincolnshire.gov.uk', 'correct email associated with problem';

        $p->delete;
    };

    subtest 'fetching problems from Open311 on staging stores user info for extant superusers' => sub {
        my $email = $superuser->email;
        my $requests_xml = qq{<?xml version="1.0" encoding="UTF-8"?>
            <service_requests>
                <request>
                    <service_request_id>lincs-123</service_request_id>
                    <status>open</status>
                    <service_name>Street light not working</service_name>
                    <description>Street light not working</description>
                    <requested_datetime>DATETIME</requested_datetime>
                    <updated_datetime>DATETIME</updated_datetime>
                    <address>1 Street</address>
                    <lat>52.656144</lat>
                    <long>-0.502566</long>
                    <contact_name>Super Duper</contact_name>
                    <contact_email>$email</contact_email>
                </request>
            </service_requests>
        };

        my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
        $requests_xml =~ s/DATETIME/$dt/gm;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
        Open311->_inject_response('/requests.xml', $requests_xml);

        my $update = Open311::GetServiceRequests->new(
            system_user => $lincs_user,
        );

        $update->create_problems( $o, $body );

        my $p = FixMyStreet::DB->resultset('Problem')->search(
            { external_id => 'lincs-123' },
            { prefetch => 'user' },
        )->first;

        ok $p, 'Found problem';
        is $p->name, "Super User", "Existing user's name set on problem";
        is $p->user->name, "Super User", "Super user's name not changed";
        is $p->user->email, $email, 'correct email associated with problem';

        $p->delete;
    };
};

done_testing();
