use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use FixMyStreet::Script::Reports;
use Open311::PopulateServiceList;
use Test::MockModule;
use t::Mock::Tilma;
use File::Temp 'tempdir';
use FixMyStreet::Script::CSVExport;
use DateTime;

my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

# Create test data
my $comment_user = $mech->create_user_ok('bristol@example.net');
my $bristol = $mech->create_body_ok( 2561, 'Bristol City Council', {
    send_method => 'Open311',
    api_key => 'key',
    endpoint => 'endpoint',
    jurisdiction => 'bristol',
    can_be_devolved => 1,
    comment_user => $comment_user,
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

# Setup Dott Bikes to cover Bristol and Westminster
my $dott = $mech->create_body_ok(2561, 'Dott');
$dott->body_areas->create({ area_id => 2504 });
$mech->create_contact_ok(
    body_id => $dott->id,
    category => 'Abandoned Dott bike or scooter',
    email => 'dott-national@example.org',
);

my $open311_contact = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Street Lighting',
    email => 'LIGHT',
);
my $open311_contact2 = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Flooding',
    email => 'FLOOD',
);

my $roadworks = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Inactive roadworks',
    email => 'roadworks@example.org',
    send_method => 'Email'
);
my $flytipping = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Flytipping',
    email => 'Alloy-FLY',
    extra => {
        _fields => [
            { code => 'Witness', values => [
                { key => 0, name => 'No' },
                { key => 1, name => 'Yes' },
            ] },
            { code => 'SizeOfIssue', values => [
                { key => 0, name => 'Small' },
                { key => 1, name => 'Medium' },
                { key => 2, name => 'Large' },
            ] },
        ]
    }
);

my $flyposting = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Flyposting',
    email => 'Alloy-FLYPOST',
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
my $graffiti = $mech->create_contact_ok(
    body_id => $bristol->id,
    category => 'Graffiti',
    email => 'Alloy-graffiti',
);

subtest 'Reports page works with no reports', sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bristol' ],
        MAPIT_URL => 'http://mapit.uk/',
        MAP_TYPE => 'Bristol',
    }, sub {
        $mech->get_ok("/reports");
        $mech->content_contains('Ashley');
        $mech->content_lacks('Backwell');
        $mech->content_lacks('Bitton');
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
    STAGING_FLAGS => { send_reports => 1 },
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'bristol',
    COBRAND_FEATURES => {
        open311_email => {
            bristol => {
                Flytipping => 'flytipping@example.org',
                flytipping_parks => 'parksemail@example.org',
            }
        }
    }
}, sub {
    subtest "flytipping extra email sent" => sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $bristol->id, 'Title', {
            cobrand => 'bristol',
            category => $flytipping->category,
            extra => { _fields => [
                { name => 'Witness', value => 1 },
                { name => 'SizeOfIssue', value => "0" },
            ] },
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        ok $p->external_id, 'Report has external ID';
        ok $p->whensent, 'Report marked as sent';
        is $p->get_extra_metadata('extra_email_sent'), 1;
        my $email = $mech->get_text_body_from_email;
        like $email, qr/Witness: Yes/;
        like $email, qr/SizeOfIssue: Small/;
    };

    subtest "flytipping in parks only sends email" => sub {
        $mech->clear_emails_ok;
        my $mock = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
        $mock->mock('_fetch_features', sub { [ { "ms:flytippingparks" => {} } ] });

        my ($p) = $mech->create_problems_for_body(1, $bristol->id, 'Title', {
            cobrand => 'bristol',
            category => $flytipping->category,
            extra => { _fields => [
                { name => 'Witness', value => 0 },
                { name => 'SizeOfIssue', value => "0" },
            ] },
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->external_id, undef, 'Report has no external ID as not sent via Open311';
        ok $p->whensent, 'Report marked as sent';
        is_deeply $p->get_extra_metadata('sent_to'), ['parksemail@example.org'];
        my $email = $mech->get_text_body_from_email;
        like $email, qr/Witness: No/;
        like $email, qr/SizeOfIssue: Small/;

        ($p) = $mech->create_problems_for_body(1, $bristol->id, 'Title', {
            cobrand => 'bristol',
            category => $flytipping->category,
            extra => { _fields => [
                { name => 'Witness', value => 1 },
                { name => 'SizeOfIssue', value => "0" },
            ] },
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->external_id, undef, 'Report has no external ID as not sent via Open311';
        ok $p->whensent, 'Report marked as sent';
        is_deeply $p->get_extra_metadata('sent_to'), ['parksemail@example.org', 'flytipping@example.org'];
        $email = $mech->get_text_body_from_email;
        like $email, qr/Witness: Yes/;
        like $email, qr/SizeOfIssue: Small/;
    };

    subtest "other category does not send email" => sub {
        $mech->clear_emails_ok;
        my $mock = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
        $mock->mock('_fetch_features', sub { [ { "ms:flytippingparks" => {} } ] });

        my ($p) = $mech->create_problems_for_body(1, $bristol->id, 'Title', {
            cobrand => 'bristol',
            category => $open311_contact->category,
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->external_id, 248;
        ok $p->whensent, 'Report marked as sent';
        is $p->get_extra_metadata('sent_to'), undef;
        $mech->email_count_is(0);
    };

    subtest "usrn populated on Alloy category" => sub {
        my $mock = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
        $mock->mock('_fetch_features', sub {
            return [] if $_[1]->{typename} eq 'flytippingparks';
            [ {
                "type" => "Feature",
                "geometry" => {"type" => "MultiLineString", "coordinates" => [[[1,1],[2,2]]]},
                "properties" => {USRN => "1234567"}
            } ]
        });

        my ($p) = $mech->create_problems_for_body(1, $bristol->id, 'Title', {
            cobrand => 'bristol',
            category => $graffiti->category,
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->get_extra_field_value('usrn'), '1234567', 'USRN added to extra field after sending to Open311';
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
            $mech->content_lacks($north_somerset_contact->category);
            $mech->content_lacks($south_gloucestershire_contact->category);

            $bristol_mock->mock('_fetch_features', sub { [ { "ms:parks" => { "ms:SITE_CODE" => 'ASHTCOES' } } ] });
            $mech->get_ok("/report/new/ajax?longitude=-2.641142&latitude=51.444878");
            $mech->content_contains($open311_contact->category);
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
        $mech->content_contains('Inactive roadworks');
    };

};

my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $bristol,
    name => 'Role',
    permissions => ['moderate', 'user_edit'],
});

my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $bristol, name => 'Staff User');
$staff_user->add_to_roles($role);
my ($p) = $mech->create_problems_for_body(1, $bristol->id, 'New title', {
    user => $staff_user,
    state => 'confirmed',
    extra => {contributed_by => $staff_user->id},
});

my @flytipping_reports = FixMyStreet::DB->resultset('Problem')->search({ category => 'Flytipping' });

subtest 'Dashboard CSV extra columns' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bristol',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
  }, sub {

    $mech->log_in_ok( $comment_user->email );
    $mech->get_ok('/dashboard?export=1');
    $mech->content_contains(',"Reported As","Staff Role"', "'Staff Role' column added");
    $mech->content_contains(',"Staff Role","Flytipping size"', "'Flytipping size' column added");
    $mech->content_contains('default,,Role', "Staff role added");
    $mech->content_contains('website,bristol,,,0', "Flytipping size added");
    $p->created(DateTime->now->subtract( days => 1));
    $p->confirmed(DateTime->now->subtract( days => 1));
    $p->update;
    for my $flytipping_report (@flytipping_reports) {
        $flytipping_report->confirmed($p->confirmed);
        $flytipping_report->update;
    };
    FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
    $mech->get_ok('/dashboard?export=1');
    $mech->content_contains(',"Reported As","Staff Role"', "'Staff Role' column added in csv export");
    $mech->content_contains(',"Staff Role","Flytipping size"', "'Flytipping size' column added in csv export");
    $mech->content_contains('default,,Role', "Staff role added added in csv export");
    $mech->content_contains('website,bristol,,,0', "Flytipping size added in csv export");
  };
};

subtest 'Dott Bikes destination handling' => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet', 'bristol'],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        dott_email => {
            bristol => 'dott-bristol@example.org'
        }
    }
  }, sub {

    subtest 'Dott report on Bristol cobrand' => sub {
        my ($p) = $mech->create_problems_for_body(1, $dott->id, 'Title', {
            cobrand => 'bristol',
            category => 'Abandoned Dott bike or scooter',
            areas => ',2561,',
        } );

        $mech->clear_emails_ok;

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        ok $p->whensent, 'Report marked as sent';
        is $p->get_extra_metadata('sent_to')->[0], 'dott-bristol@example.org', 'sent_to extra metadata set';

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
        is $email->header('To'), 'Dott <dott-bristol@example.org>', 'email sent to correct address';
    };

    subtest 'Dott report in Bristol on FMS cobrand' => sub {
        my ($p) = $mech->create_problems_for_body(1, $dott->id, 'Title', {
            cobrand => 'fixmystreet',
            category => 'Abandoned Dott bike or scooter',
            areas => ',2561,',
        } );

        $mech->clear_emails_ok;

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        ok $p->whensent, 'Report marked as sent';
        is $p->get_extra_metadata('sent_to')->[0], 'dott-bristol@example.org', 'sent_to extra metadata set';

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
        is $email->header('To'), 'Dott <dott-bristol@example.org>', 'email sent to correct address';
    };

    subtest 'Dott report in Westminster on FMS cobrand' => sub {
        my ($p) = $mech->create_problems_for_body(1, $dott->id, 'Title', {
            cobrand => 'fixmystreet',
            category => 'Abandoned Dott bike or scooter',
            areas => ',2504,',
        } );

        $mech->clear_emails_ok;

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        ok $p->whensent, 'Report marked as sent';
        is $p->get_extra_metadata('sent_to')->[0], 'dott-national@example.org', 'sent_to extra metadata set';

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
        is $email->header('To'), 'Dott <dott-national@example.org>', 'email sent to correct address';
    };
  };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['bristol'],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {}
}, sub {

    subtest 're-categorising auto-resends' => sub {
        my ($report) = $mech->create_problems_for_body(1, $bristol->id, 'Title', {
            cobrand => 'bristol',
            category => $open311_contact->category,
            areas => ',2561,',
        } );
        $report->update({ send_state => 'sent', send_method_used => 'Open311' });

        $mech->log_in_ok($comment_user->email);
        $mech->get_ok('/admin/report_edit/' . $report->id);

        $mech->submit_form_ok({ with_fields => { category => $open311_contact2->category } });
        $report->discard_changes;
        is $report->send_state, 'sent', "Changed from Confirm category to Confirm category, remain sent";

        $mech->submit_form_ok({ with_fields => { category => $flyposting->category } });
        $report->discard_changes;
        is $report->send_state, 'unprocessed', "Changed from Confirm category to Alloy category, set to resend";

        $report->update({ send_state => 'sent', send_method_used => 'Open311' });
        $mech->submit_form_ok({ with_fields => { category => $flytipping->category } });
        $report->discard_changes;
        is $report->send_state, 'sent', "Changed from Alloy category to Alloy category, remain sent";

        $mech->submit_form_ok({ with_fields => { category => $roadworks->category } });
        $report->discard_changes;
        is $report->send_state, 'unprocessed', "Changed from Alloy category to email category, set to resend";

        $report->update({ send_state => 'sent', send_method_used => 'Open311', category => $flytipping->category });
        $mech->submit_form_ok({ with_fields => { category => $open311_contact->category } });
        $report->discard_changes;
        is $report->send_state, 'unprocessed', "Changed from Alloy category to Confirm category, set to resend";
    };
};

done_testing();
