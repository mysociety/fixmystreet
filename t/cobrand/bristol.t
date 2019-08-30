use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use Open311::PopulateServiceList;

# Create test data
my $body = $mech->create_body_ok( 2561, 'Bristol County Council', {
    send_method => 'Open311',
    can_be_devolved => 1
});

my $open311_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street Lighting',
    email => 'LIGHT',
);
my $email_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'potholes@example.org',
    send_method => 'Email'
);

subtest 'Reports page works with no reports', sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bristol' ],
        MAPIT_URL => 'http://mapit.uk/',
        MAP_TYPE => 'Bristol',
    }, sub {
        $mech->get_ok("/reports");
    };
};

subtest 'Only Open311 categories are shown on Bristol cobrand', sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bristol' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok("/report/new/ajax?latitude=51.494885&longitude=-2.602237");
        $mech->content_contains($open311_contact->category);
        $mech->content_lacks($email_contact->category);
    };
};

subtest 'All categories are shown on FMS cobrand', sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok("/report/new/ajax?latitude=51.494885&longitude=-2.602237");
        $mech->content_contains($open311_contact->category);
        $mech->content_contains($email_contact->category);
    };
};

subtest 'check services override' => sub {
    my $processor = Open311::PopulateServiceList->new();

    my $meta_xml = '<?xml version="1.0" encoding="utf-8"?>
<service_definition>
    <service_code>LIGHT</service_code>
    <attributes>
        <attribute>
            <variable>true</variable>
            <code>easting</code>
            <datatype>string</datatype>
            <required>true</required>
            <order>1</order>
            <description>Easting</description>
        </attribute>
        <attribute>
            <variable>true</variable>
            <code>size</code>
            <datatype>string</datatype>
            <required>true</required>
            <order>2</order>
            <description>How big is the pothole</description>
        </attribute>
    </attributes>
</service_definition>
    ';

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'services/LIGHT.xml' => $meta_xml }
    );

    $processor->_current_open311( $o );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bristol' ],
    }, sub {
        $processor->_current_body( $body );
    };
    $processor->_current_service( { service_code => 'LIGHT' } );
    $processor->_add_meta_to_contact( $open311_contact );

    my $extra = [ {
        automated => 'server_set',
        variable => 'true',
        code => 'easting',
        datatype => 'string',
        required => 'true',
        order => 1,
        description => 'Easting',
    }, {
        variable => 'true',
        code => 'size',
        datatype => 'string',
        required => 'true',
        order => 2,
        description => 'How big is the pothole',
    } ];

    $open311_contact->discard_changes;
    is_deeply $open311_contact->get_extra_fields, $extra, 'Easting has automated set';
};

done_testing();
