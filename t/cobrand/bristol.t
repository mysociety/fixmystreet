use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use FixMyStreet::Script::Reports;
use Open311::PopulateServiceList;

# Create test data
my $comment_user = $mech->create_user_ok('bristol@example.net');
my $body = $mech->create_body_ok( 2561, 'Bristol County Council', {
    send_method => 'Open311',
    can_be_devolved => 1,
    comment_user => $comment_user,
}, {
    cobrand => 'bristol',
});

my $open311_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street Lighting',
    email => 'LIGHT',
);
my $open311_edited_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Flooding',
    email => 'FLOOD',
    send_method => '',
);
my $email_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'potholes@example.org',
    send_method => 'Email'
);
my $roadworks = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Inactive roadworks',
    email => 'roadworks@example.org',
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
        $mech->content_contains($open311_edited_contact->category);
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
        $mech->content_contains($open311_edited_contact->category);
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
    );
    Open311->_inject_response('/services/LIGHT.xml', $meta_xml);

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

subtest "idle roadworks automatically closed" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'bristol',
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $body->id, 'Title', {
            cobrand => 'bristol',
            category => $roadworks->category,
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        ok $p->whensent, 'Report marked as sent';
        is $p->get_extra_metadata('sent_to')->[0], 'roadworks@example.org', 'sent_to extra metadata set';
        is $p->state, 'closed', 'report closed having sent email';
        is $p->comments->count, 1, 'comment added';
        like $p->comments->first->text, qr/This issue has been forwarded on/, 'correct comment text';

        $mech->email_count_is(1);
    };
};

done_testing();
