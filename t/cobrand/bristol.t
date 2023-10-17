use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use FixMyStreet::Script::Reports;
use Open311::PopulateServiceList;
use Test::MockModule;
use t::Mock::Tilma;

my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

# Create test data
my $comment_user = $mech->create_user_ok('bristol@example.net');
my $bristol = $mech->create_body_ok( 2561, 'Bristol City Council', {
    send_method => 'Open311',
    can_be_devolved => 1,
    comment_user => $comment_user,
}, {
    cobrand => 'bristol',
});
$comment_user->update({ from_body => $bristol->id });
$comment_user->user_body_permissions->create({ body => $bristol, permission_type => 'report_edit' });

# Setup Bristol to cover North Somerset and South Gloucestershire
$bristol->body_areas->create({ area_id => 2642 });
$bristol->body_areas->create({ area_id => 2608 });
my $north_somerset = $mech->create_body_ok(2642, 'North Somerset Council');
my $south_gloucestershire = $mech->create_body_ok(2608, 'South Gloucestershire Council');

# Setup National Highways to cover Bristol, North Somerset and South Gloucestershire
my $national_highways = $mech->create_body_ok(2561, 'National Highways');
$national_highways->body_areas->create({ area_id => 2642 });
$national_highways->body_areas->create({ area_id => 2608 });

my $open311_contact = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Street Lighting',
    email => 'LIGHT',
);
my $open311_edited_contact = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Flooding',
    email => 'FLOOD',
    send_method => '',
);
my $email_contact = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Potholes',
    email => 'potholes@example.org',
    send_method => 'Email'
);
my $roadworks = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Inactive roadworks',
    email => 'roadworks@example.org',
    send_method => 'Email'
);
my $north_somerset_contact = $mech->create_contact_ok(
    body_id => $north_somerset->id,
    category => 'North Somerset Potholes',
    email => 'somerset-potholes@example.org',
    send_method => 'Email'
);
my $south_gloucestershire_contact = $mech->create_contact_ok(
    body_id => $south_gloucestershire->id,
    category => 'South Gloucestershire Potholes',
    email => 'glos-potholes@example.org',
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
        $processor->_current_body( $bristol );
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

        my ($p) = $mech->create_problems_for_body(1, $bristol->id, 'Title', {
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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bristol', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    my $bristol_mock = Test::MockModule->new('FixMyStreet::Cobrand::Bristol');
    $bristol_mock->mock('_fetch_features', sub { [] });

    # Make sure we're handling National Highways correctly by testing on and off NH roads.
    my $national_highways_mock = Test::MockModule->new('FixMyStreet::Cobrand::HighwaysEngland');

    foreach my $host (qw/bristol www/) {
        foreach my $is_on_nh_road (1, 0) {
            $national_highways_mock->mock('report_new_is_on_he_road', sub { $is_on_nh_road });

            subtest "reports on $host cobrand within Bristol boundaries go to Bristol" . ($is_on_nh_road ? ' if on NH road' : '') => sub {
                $mech->host("$host.fixmystreet.com");
                $mech->get_ok("/report/new/ajax?latitude=51.494885&longitude=-2.602237");
                $mech->content_contains($open311_contact->category);
                $mech->content_contains($open311_edited_contact->category);
                $mech->content_lacks($north_somerset_contact->category);
                $mech->content_lacks($south_gloucestershire_contact->category);
            };
        }
    }

    foreach my $host (qw/bristol www/) {
        subtest "reports on $host cobrand in Ashton Court and Stoke Park Estate show Bristol categories" => sub {
            $mech->host("$host.fixmystreet.com");

            $bristol_mock->mock('_fetch_features', sub { [ { "ms:parks" => { "ms:SITE_CODE" => 'STOKPAES' } } ] });
            $mech->get_ok("/report/new/ajax?longitude=-2.551191&latitude=51.495216");
            $mech->content_contains($open311_contact->category);
            $mech->content_contains($open311_edited_contact->category);
            $mech->content_lacks($north_somerset_contact->category);
            $mech->content_lacks($south_gloucestershire_contact->category);

            $bristol_mock->mock('_fetch_features', sub { [ { "ms:parks" => { "ms:SITE_CODE" => 'ASHTCOES' } } ] });
            $mech->get_ok("/report/new/ajax?longitude=-2.641142&latitude=51.444878");
            $mech->content_contains($open311_contact->category);
            $mech->content_contains($open311_edited_contact->category);
            $mech->content_lacks($north_somerset_contact->category);
            $mech->content_lacks($south_gloucestershire_contact->category);
        };
    }

    subtest 'locations outside Bristol and not in park' => sub {
        $bristol_mock->mock('_fetch_features', sub { [] });

        $mech->host('bristol.fixmystreet.com');
        $mech->get_ok("/report/new/ajax?longitude=-2.654832&latitude=51.452340");
        $mech->content_contains("That location is not covered by Bristol City Council");

        $mech->host('www.fixmystreet.com');
        $mech->get_ok("/report/new/ajax?longitude=-2.654832&latitude=51.452340");
        $mech->content_lacks($open311_contact->category);
        $mech->content_lacks($open311_edited_contact->category);
        $mech->content_lacks($south_gloucestershire_contact->category);
        $mech->content_contains($north_somerset_contact->category);
    };

    subtest 'check report pages after creation' => sub {
        $mech->host('bristol.fixmystreet.com');
        my ($p) = $mech->create_problems_for_body(1, $bristol->id, 'Title', {
            cobrand => 'bristol',
            category => $open311_contact->category,
            latitude => 51.494885,
            longitude => -2.602237,
            areas => ',2561,66009,148659,164861,',
        } );
        $mech->log_in_ok($comment_user->email);
        $mech->get_ok('/admin/report_edit/' . $p->id);
        $mech->content_contains('Flooding');
        $mech->content_contains('Inactive roadworks');
    };

};

done_testing();
