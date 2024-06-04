use CGI::Simple;
use File::Temp 'tempdir';
use Test::MockModule;
use Test::MockTime qw(:all);
use Test::Warn;
use DateTime;
use JSON::MaybeXS;
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Reports;
use Open311::PostServiceRequestUpdates;
use Open311::GetServiceRequestUpdates;
use Open311::PopulateServiceList;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

# Create test data
my $user = $mech->create_user_ok( 'bromley@example.com', name => 'Bromley' );
my $standard_user = $mech->create_user_ok('test@example.com', name => 'Bob Betts');
my $body = $mech->create_body_ok( 2482, 'Bromley Council', {
    can_be_devolved => 1, send_extended_statuses => 1, comment_user => $user,
    send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1
}, {
    cobrand => 'bromley'
});
my $lewisham = $mech->create_body_ok( 2492, 'Lewisham Borough Council');
my $staffuser = $mech->create_user_ok( 'staff@example.com', name => 'Staffie', from_body => $body );
my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $body, name => 'Role A', permissions => ['moderate', 'user_edit', 'report_mark_private', 'report_inspect', 'contribute_as_body'] });
my $roleB = FixMyStreet::DB->resultset("Role")->create({ body => $body, name => 'Role B' });
$staffuser->add_to_roles($role);
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Other',
    email => 'LIGHT',
);
$contact->set_extra_metadata(id_field => 'service_request_id_ext');
$contact->set_extra_fields(
    { code => 'easting', datatype => 'number', },
    { code => 'northing', datatype => 'number', },
    { code => 'service_request_id_ext', datatype => 'number', },
);
$contact->update;
my $streetlights = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Streetlights',
    email => 'LIGHT',
);
$streetlights->set_extra_fields(
    { code => 'feature_id', datatype => 'string', automated => 'hidden_field' },
);
$streetlights->update;

my $tfl = $mech->create_body_ok( 2482, 'TfL', {}, { cobrand => 'tfl' });
$mech->create_contact_ok(
    body_id => $tfl->id,
    category => 'Traffic Lights',
    email => 'tfl@example.org',
);

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    latitude => 51.402096,
    longitude => 0.015784,
    cobrand => 'bromley',
    areas => '2482,8141',
    user => $user,
    send_method_used => 'Open311',
    whensent => 'now()',
    send_state => 'sent',
    external_id => '456',
    extra => {
        contributed_by => $staffuser->id,
    },
});
my $report = $reports[0];

for my $update ('in progress', 'unable to fix') {
    FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => $update,
        problem_id => $report->id,
        user_id    => $user->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "This update marks it as $update",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
}

# Test Bromley special casing of 'unable to fix'
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains( 'marks it as in progress' );
$mech->content_contains( 'State changed to: In progress' );
$mech->content_contains( 'marks it as unable to fix' );
$mech->content_contains( 'State changed to: No further action' );

subtest 'Check updates not sent for staff with no text' => sub {
    my $comment = FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => 'unable to fix',
        problem_id => $report->id,
        user_id    => $staffuser->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 0, "comment sending not attempted";
    is $comment->send_state, 'skipped', "skipped sending comment";
};

subtest 'Updates from staff with no text but with private comments are sent' => sub {
    my $comment = FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => 'unable to fix',
        problem_id => $report->id,
        user_id    => $staffuser->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
    $comment->send_state('unprocessed');
    $comment->set_extra_metadata(private_comments => 'This comment has secret notes');
    $comment->update;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        Open311->_inject_response('/servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>42</update_id></request_update></service_request_updates>');

        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;

        $comment->discard_changes;
        ok $comment->whensent, "comment was sent";
        is $comment->send_state, 'sent', "didn't skip sending comment";

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('title'), 'n/a';
        like $c->param('description'), qr/Private comments: This comment has secret notes/, 'private comments included in update description';
    };
};

for my $test (
    {
        desc => 'testing special Open311 behaviour',
        updates => {},
        expected => {
          'attribute[easting]' => 540315,
          'attribute[northing]' => 168935,
          'attribute[service_request_id_ext]' => $report->id,
          'attribute[report_title]' => 'Test Test 1 for ' . $body->id . ' | ROLES: Role A',
          'jurisdiction_id' => 'FMS',
          address_id => undef,
        },
    },
    {
        desc => 'testing Open311 behaviour with no map click or postcode',
        updates => {
            used_map => 0,
            postcode => ''
        },
        expected => {
          'attribute[easting]' => 540315,
          'attribute[northing]' => 168935,
          'attribute[service_request_id_ext]' => $report->id,
          'jurisdiction_id' => 'FMS',
          'address_id' => '#NOTPINPOINTED#',
        },
    },
    {
        desc => 'asset ID',
        feature_id => '1234',
        expected => {
          'attribute[service_request_id_ext]' => $report->id,
          'attribute[report_title]' => 'Test Test 1 for ' . $body->id . ' | ID: 1234 | ROLES: Role A',
        },
    },
) {
    subtest $test->{desc}, sub {
        $report->$_($test->{updates}->{$_}) for keys %{$test->{updates}};
        $report->$_(undef) for qw/ whensent send_method_used external_id /;
        $report->send_state('unprocessed');
        $report->set_extra_fields({ name => 'feature_id', value => $test->{feature_id} })
            if $test->{feature_id};
        $report->update;
        FixMyStreet::override_config {
            STAGING_FLAGS => { send_reports => 1 },
            ALLOWED_COBRANDS => [ 'fixmystreet', 'bromley' ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            FixMyStreet::Script::Reports::send();
        };
        $report->discard_changes;
        ok $report->whensent, 'Report marked as sent';
        is $report->send_method_used, 'Open311', 'Report sent via Open311';
        is $report->external_id, 248, 'Report has right external ID';

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param($_), $test->{expected}->{$_}, "Request had correct $_"
            for keys %{$test->{expected}};
    };
}

subtest 'ensure private_comments are added to open311 description' => sub {
    $report->set_extra_metadata(private_comments => 'Secret notes go here');
    $report->send_state('unprocessed');
    $report->update;

    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet', 'bromley' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::Script::Reports::send();
    };

    $report->discard_changes;
    is $report->send_state, 'sent', 'Report marked as sent';
    unlike $report->detail, qr/Private comments/, 'private comments not saved to report detail';

    my $req = Open311->test_req_used;
    my $c = CGI::Simple->new($req->content);
    like $c->param('description'), qr/Private comments: Secret notes go here/, 'private comments included in description';
};

subtest 'Private comments on updates are added to open311 description' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['bromley', 'tfl'],
    }, sub {
        $report->comments->delete;

        Open311->_inject_response('/servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>42</update_id></request_update></service_request_updates>');

        $mech->log_out_ok;
        $mech->log_in_ok($staffuser->email);
        $mech->host('bromley.fixmystreet.com');

        $mech->get_ok('/report/' . $report->id);

        $mech->submit_form_ok( {
                with_fields => {
                    submit_update => 1,
                    update => 'Test',
                    private_comments => 'Secret update notes',
                    fms_extra_title => 'DR',
                    first_name => 'Bromley',
                    last_name => 'Council',
                },
            },
            'update form submitted'
        );

        is $report->comments->count, 1, 'comment was added';
        my $comment = $report->comments->first;
        is $comment->get_extra_metadata('private_comments'), 'Secret update notes', 'private comments saved to comment';

        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;

        $comment->discard_changes;
        ok $comment->whensent, 'Comment marked as sent';
        unlike $comment->text, qr/Private comments/, 'private comments not saved to update text';

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        like $c->param('description'), qr/Private comments: Secret update notes/, 'private comments included in update description';
    };
};

for my $test (
    {
        cobrand => 'bromley',
        fields => {
            submit_update   => 1,
            username_register => 'unregistered@example.com',
            update          => 'Update from an unregistered user',
            add_alert       => undef,
            first_name            => 'Unreg',
            last_name            => 'User',
            fms_extra_title => 'DR',
            may_show_name   => undef,
        }
    },
    {
        cobrand => 'fixmystreet',
        fields => {
            submit_update   => 1,
            username_register => 'unregistered@example.com',
            update          => 'Update from an unregistered user',
            add_alert       => undef,
            name            => 'Unreg User',
            fms_extra_title => 'DR',
            may_show_name   => undef,
        }
    },
)
{
    subtest 'check Bromley update emails via ' . $test->{cobrand} . ' cobrand are correct' => sub {
        $mech->log_out_ok();
        $mech->clear_emails_ok();

        my $report_id = $report->id;

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ $test->{cobrand} ],
        }, sub {
            $mech->get_ok("/report/$report_id");
            $mech->submit_form_ok(
                {
                    with_fields => $test->{fields}
                },
                'submit update'
            );
        };
        $mech->content_contains('Nearly done! Now check your email');

        my $body = $mech->get_text_body_from_email;
        like $body, qr/This update will be sent to Bromley Council/i, "Email indicates problem will be sent to Bromley";
        unlike $body, qr/Note that we do not send updates to/i, "Email does not say updates aren't sent to Bromley";

        my $unreg_user = FixMyStreet::DB->resultset('User')->find( { email => 'unregistered@example.com' } );

        ok $unreg_user, 'found user';

        $mech->delete_user( $unreg_user );
    };
}

subtest 'check display of TfL reports' => sub {
    $mech->create_problems_for_body( 1, $tfl->id, 'TfL Test', {
        latitude => 51.402096,
        longitude => 0.015784,
        cobrand => 'bromley',
        user => $user,
    });
    $mech->get_ok( '/report/' . $report->id );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->follow_link_ok({ text_regex => qr/Back to all reports/i });
    };
    $mech->content_like(qr{<a title="TfL Test[^>]*www.example.org[^>]*><img[^>]*grey});
    $mech->content_like(qr{<a title="Test Test[^>]*href="/[^>]*><img[^>]*yellow});
};

subtest 'check geolocation overrides' => sub {
    my $cobrand = FixMyStreet::Cobrand::Bromley->new;
    foreach my $test (
        { query => 'Main Rd, BR1', town => 'Bromley', string => 'Main Rd' },
        { query => 'Main Rd, BR3', town => 'Beckenham', string => 'Main Rd' },
        { query => 'Main Rd, BR4', town => 'West Wickham', string => 'Main Rd' },
        { query => 'Main Rd, BR5', town => 'Orpington', string => 'Main Rd' },
        { query => 'Main Rd, BR7', town => 'Chislehurst', string => 'Main Rd' },
        { query => 'Main Rd, BR8', town => 'Swanley', string => 'Main Rd' },
        { query => 'Old Priory Avenue', town => 'BR6 0PL', string => 'Old Priory Avenue' },
    ) {
        my $res = $cobrand->disambiguate_location($test->{query});
        is $res->{town}, $test->{town}, "Town matches $test->{town}";
        is $res->{string}, $test->{string}, "String matches $test->{string}";
    }
};

subtest 'check title field on report page for staff' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['bromley', 'tfl'],
    }, sub {
        $mech->get_ok( '/report/' . $report->id );
        $mech->content_contains('MRS');
    };
};

subtest 'check heatmap page' => sub {
    $user->update({ area_ids => [ 60705 ] });
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => { category_groups => { bromley => 1 }, heatmap => { bromley => 1 } },
    }, sub {
        $user->update({ from_body => $body->id });
        $mech->log_in_ok($user->email);
        $mech->get_ok('/dashboard/heatmap?end_date=2018-12-31');
        $mech->get_ok('/dashboard/heatmap?filter_category=RED&ajax=1');
    };
    $user->update({ area_ids => undef });
};

subtest 'category restrictions for roles restricts reporting categories for users with that role' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['bromley', 'tfl'],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $potholes = $mech->create_contact_ok(
            body_id => $body->id,
            category => 'Potholes',
            email => 'potholes@example.org',
        );
        my $flytipping = $mech->create_contact_ok(
            body_id => $body->id,
            category => 'Flytipping',
            email => 'flytipping@example.org',
        );
        $user->set_extra_metadata(assigned_categories_only => 1);
        $user->update;
        my $role = $user->roles->create({
            body => $body,
            name => 'Out of hours',
            permissions => ['moderate', 'planned_reports'],
        });
        $role->set_extra_metadata('categories', [$potholes->id]);
        $role->update;
        $user->add_to_roles($role);

        $mech->log_in_ok($user->email);
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'BR1 3UH', } },
            "submit location" );
        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->content_contains('Potholes');
        $mech->content_lacks('Flytipping');

        # TfL categories should always be displayed, regardless of role restrictions.
        $mech->content_contains('Traffic Lights');
    };
};

subtest 'Dashboard CSV extra columns' => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'bromley',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->log_in_ok($staffuser->email);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Reported As","Staff User","Staff Role"');
        $mech->content_like(qr/bromley,,[^,]*staff\@example.com,"Role A"/);

        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Reported As","Staff User","Staff Role"');
        $mech->content_like(qr/bromley,,[^,]*staff\@example.com,"Role A"/);

        $mech->get_ok('/dashboard?export=1&role=' . $role->id);
        $mech->content_contains("Role A");
        $mech->get_ok('/dashboard?export=1&role=' . $roleB->id);
        $mech->content_lacks("Role A");
    };
};


my $bromley_parks = Test::MockModule->new('BromleyParks');
$bromley_parks->mock('_db_results', sub {
    my ($search) = @_;

    if ($search eq 'Alexandra Rec') {
        return [{ northing => 170901, easting => 535688 }];
    } elsif ($search eq 'The Green') {
        return [{ northing => 162175, easting => 547189 }];
    }
});

subtest 'parks lookup' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk',
    }, sub {
        $mech->log_out_ok;

        $mech->get_ok('/');
        $mech->submit_form_ok({ with_fields => { pc => 'Alexandra Rec' } });
        $mech->content_contains('51.4208');

        $mech->get_ok('/');
        $mech->submit_form_ok({ with_fields => { pc => 'The Green' } });
        $mech->content_contains('51.3396');
    };
};

subtest 'check_within_days' => sub {
    for my $test (
        {
            today => '2021-03-19',
            check => '2021-03-18',
            days => 1,
            is_true => 1,
            name => 'tomorrow',
        },
        {
            today => '2021-03-19',
            check => '2021-03-17',
            days => 1,
            is_true => 0,
            name => 'day after tomorrow',
        },
        {
            today => '2021-03-22',
            check => '2021-03-19',
            days => 1,
            is_true => 1,
            name => 'over weekend',
        },
        {
            today => '2021-03-23',
            check => '2021-03-19',
            days => 1,
            is_true => 0,
            name => 'tuesday',
        },
        {
            today => '2021-03-23',
            check => '2021-03-19',
            days => 1,
            is_true => 1,
            name => 'tuesday future',
            future => 1,
        },
        {
            today => '2021-03-18',
            check => '2021-03-17',
            days => 2,
            is_true => 0,
            name => 'day after tomorrow future',
            future => 1,
        },
        {
            today => '2021-03-20',
            check => '2021-03-19',
            days => 1,
            is_true => 0,
            name => 'saturday not ahead of friday',
            future => 1,
        },
    ) {
        subtest $test->{name} => sub {
            set_fixed_time($test->{today} . 'T12:00:00Z');
            my $date = DateTime::Format::W3CDTF->parse_datetime($test->{check});

            if ( $test->{is_true} ) {
                ok(FixMyStreet::Cobrand::Bromley->within_working_days($date, $test->{days}, $test->{future}));
            } else {
                ok(!FixMyStreet::Cobrand::Bromley->within_working_days($date, $test->{days}, $test->{future}));
            }

        };
    }
};

for my $test (
    {
        code => 'SL_LAMP',
        result => 'feature_id',
        description => 'feature_id added to lamp code'
    },
    {
        code => 'ASL_LAMP',
        result => undef,
        description => 'feature_id not added to non-lamp code'
    }
) {
    subtest 'check open311_contact_meta_override' => sub {

        my $processor = Open311::PopulateServiceList->new();

        my $meta_xml = '<?xml version="1.0" encoding="utf-8"?>
<service_definition>
    <service_code>DUMMY</service_code>
    <attributes>
        <attribute>
            <automated>server_set</automated>
            <code>hint</code>
            <datatype>string</datatype>
            <datatype_description></datatype_description>
            <description>Lamp on during day</description>
            <order>1</order>
            <required>false</required>
            <variable>false</variable>
        </attribute>
    </attributes>
</service_definition>
    ';

        my $o = Open311->new(
            jurisdiction => 'mysociety',
            endpoint => 'http://example.com',
        );
        Open311->_inject_response('/services/' . $test->{code} . '.xml', $meta_xml);

        $processor->_current_open311( $o );
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'bromley' ],
        }, sub {
            $processor->_current_body( $body );
        };
        $processor->_current_service( { service_code => $test->{code}, service_name => 'Lamp on during day' } );
        $processor->_add_meta_to_contact( $contact );
        $contact->discard_changes;
        my @extra_fields = $contact->get_extra_fields;
        is $extra_fields[0][2]->{code}, $test->{result}, $test->{description};
    };
}

subtest 'Can select asset that is in Lewisham area on Bromley Cobrand' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['bromley', 'tfl'],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_in_ok('test@example.com');
        $mech->get_ok('/report/new/?longitude=0.005357&latitude=51.418776');
        $mech->content_contains('That location is not covered by Bromley Council', 'Area in Lewisham not reportable on Bromley cobrand');
        $mech->get_ok('/report/new/?longitude=-0.071410&latitude=51.419275&category=Streetlights');
        $mech->submit_form_ok( { with_fields => {
                title => 'Lamp issue in Lewisham on Bromley',
                detail => 'Lamp issue over the border',
                feature_id => 'A-48-24',
                longitude => 0.005357,
                latitude => 51.418776,
                fms_extra_title => 'Mr'
            }}, 'Location in Lewisham ok as clicked from Bromley location onto Bromley asset');
        my $problem = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $problem->title, 'Lamp issue in Lewisham on Bromley', 'Report has been made';
        is $problem->body, 'Bromley Council', 'Problem on correct body';
    };
};

subtest 'Can select asset that is in Lewisham area on FMS' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['fixmystreet', 'tfl'],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_in_ok('test@example.com');
        $mech->get_ok('/report/new/?longitude=0.005357&latitude=51.418776');
        $mech->content_contains('We do not yet have details for the council that covers this location', 'Lewisham does not have Bromley categories');
        $mech->get_ok('/report/new/?longitude=-0.071410&latitude=51.419275&category=Streetlights');
        $mech->submit_form_ok( { with_fields => {
                title => 'Lamp issue in Lewisham on FMS',
                detail => 'Lamp issue over the border',
                feature_id => 'A-48-26',
                longitude => 0.005357,
                latitude => 51.418776,
                fms_extra_title => 'Mr'
            }}, 'Location in Lewisham ok as clicked from Bromley location onto Bromley asset');
        my $problem = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $problem->title, 'Lamp issue in Lewisham on FMS', 'Report has been made';
        is $problem->body, 'Bromley Council', 'Problem on correct body';
    };
};

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

subtest 'redirecting of reports between backends' => sub {
    my $integ = Test::MockModule->new('SOAP::Lite');
    $integ->mock(call => sub {
        my ($cls, @args) = @_;
        my $method = $args[0]->name;
        if ($method eq 'GetEventType') {
            return SOAP::Result->new(result => {
                Workflow => { States => { State => [
                    { CoreState => 'New', Name => 'New', Id => 15001 },
                    { CoreState => 'Pending', Name => 'Unallocated', Id => 15002 },
                    { CoreState => 'Pending', Name => 'Allocated to Crew', Id => 15003 },
                    { CoreState => 'Closed', Name => 'Completed', Id => 15004,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 201, Name => '' },
                        { ResolutionCodeId => 202, Name => 'Spillage on Arrival' },
                      ] } },
                    { CoreState => 'Closed', Name => 'Not Completed', Id => 15005,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 203, Name => 'Nothing Found' },
                        { ResolutionCodeId => 204, Name => 'Too Heavy' },
                        { ResolutionCodeId => 205, Name => 'Inclement Weather' },
                      ] } },
                    { CoreState => 'Closed', Name => 'Rejected', Id => 15006,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 206, Name => 'Out of Time' },
                        { ResolutionCodeId => 207, Name => 'Duplicate' },
                      ] } },
                ] } },
            });
        } elsif ($method eq 'GetEvent') {
            return SOAP::Result->new(result => {
                Guid => 'hmm',
                Id => 'id',
                Data => {
                    ExtensibleDatum => [
                        {
                            DatatypeId => 55418,
                            DatatypeName => "Veolia Notes",
                            Value => "Outgoing notes from Echo",
                        },
                    ],
                },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    $mech->create_contact_ok(
        body_id => $body->id,
        category => 'Referred to LB Bromley Streets',
        email => 'LBB_RRE_FROM_VEOLIA_STREETS',
    );
    $mech->create_contact_ok(
        body_id => $body->id,
        category => 'Referred to Veolia Streets',
        email => '3045',
    );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        COBRAND_FEATURES => {
            echo => { bromley => {
                url => 'https://www.example.org/',
                receive_action => 'action',
                receive_username => 'un',
                receive_password => 'password',
            } },
            waste => { bromley => 1 },
        },
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my ($report) = $mech->create_problems_for_body(1, $body->id, 'Street issue', {
            category => 'Street issue',
            whensent => DateTime->now,
        });

        my $in = $mech->echo_notify_xml('guid', 2104, 15004, 1252);

        subtest 'A report sent to Confirm, then redirected to Echo' => sub {
            $report->update({ external_id => 12345 });

            my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
                <service_requests_updates>
                <request_update>
                <update_id>UPDATE_1</update_id>
                <service_request_id>12345</service_request_id>
                <status>REFERRED_TO_VEOLIA_STREETS</status>
                <description>This is a handover note</description>
                <updated_datetime>UPDATED_DATETIME</updated_datetime>
                </request_update>
                </service_requests_updates>
            };
            my $update_dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new);
            $requests_xml =~ s/UPDATED_DATETIME/$update_dt/g;

            my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
            Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

            my $update = Open311::GetServiceRequestUpdates->new(
                system_user => $staffuser,
                current_open311 => $o,
                current_body => $body,
            );
            $update->process_body;
            $report->discard_changes;
            is $report->comments->count, 1;
            is $report->whensent, undef;
            is $report->get_extra_field_value('Notes'), 'This is a handover note';
            is $report->category, 'Referred to Veolia Streets';
        };
        subtest '...then redirected back to Confirm' => sub {
            $report->update({ external_id => 'guid', whensent => DateTime->now, send_method_used => 'Open311' });
            $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
            is $report->comments->count, 2, 'A new update';
            $report->discard_changes;
            is $report->external_id, 12345, 'ID changed back';
            is $report->state, 'in progress', 'A state change';
            is $report->category, 'Referred to LB Bromley Streets';
            isnt $report->whensent, undef;

            Open311->_inject_response('/servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>42</update_id></request_update></service_request_updates>');

            my $updates = Open311::PostServiceRequestUpdates->new();
            $updates->send;

            my $req = Open311->test_req_used;
            my $c = CGI::Simple->new($req->content);
            is $c->param('status'), 'REFERRED_TO_LBB_STREETS';
            is $c->param('service_code'), 'LBB_RRE_FROM_VEOLIA_STREETS';
            like $c->param('description'), qr/Handover notes - Outgoing notes from Echo/;
        };
        subtest 'A report sent to Echo, redirected to Confirm' => sub {
            $report->comments->delete;
            $report->unset_extra_metadata('original_bromley_external_id');
            $report->update({ external_id => 'guid' });
            $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
            is $report->comments->count, 1, 'A new update';
            $report->discard_changes;
            is $report->whensent, undef;
            is $report->external_id, 'guid', 'ID not changed';
            is $report->state, 'in progress', 'A state change';
            is $report->category, 'Referred to LB Bromley Streets';
            FixMyStreet::Script::Reports::send();

            my $req = Open311->test_req_used;
            my $c = CGI::Simple->new($req->content);
            is $c->param('service_code'), 'LBB_RRE_FROM_VEOLIA_STREETS';
            like $c->param('description'), qr/Handover notes - Outgoing notes from Echo/;
        };
    };

};

subtest "comment on a closed echo report result in a resend under 'Referred to Veolia Streets'" => sub {
    my $event_guid = '05a10cb2-44c9-48d9-92a2-cc6788994bae';
    my $event_id = 123;

    my $echo = Test::MockModule->new('Integrations::Echo');

    $echo->mock('GetEvent', sub { {
        Guid => $event_guid,
        ResolvedDate => { DateTime => '2024-03-21T12:00:00Z' },
        Id => $event_id,
    } } );

    my ($report) = $mech->create_problems_for_body(1, $body->id, 'echo report', {
            cobrand => 'bromley',
            whensent => 'now()',
            send_state => 'sent',
            send_method_used => 'Open311',
            external_id => $event_guid,
        });
    $report->state('closed');
    my $comment = $report->add_to_comments({
        text => 'comment on closed event',
        user => $user,
        mark_open => 1,
    });
    $report->update;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $report->discard_changes;
    is $report->get_extra_metadata('open311_category_override'), 'Referred to Veolia Streets', 'category override applied';
    is $report->send_state, 'unprocessed', 'report set to be resent';

    $comment->discard_changes;
    is $comment->send_state, 'skipped', "skipped sending comment";

    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'bromley' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::Script::Reports::send();
    };

    $report->discard_changes;
    is $report->send_state, 'sent', 'report was resent';

    my $req = Open311->test_req_used;
    my $c = CGI::Simple->new($req->content);
    my $detail = $report->detail;
    is $c->param('attribute[Event_ID]'), $event_id, 'old event ID included in attributes';
    like $c->param('description'), qr/Closed report has a new comment: comment on closed event\r\nBromley pkg-tcobrandbromleyt-bromley\@example.com\r\n$detail/, 'Comment on closed report included in new report description';
};

done_testing();
