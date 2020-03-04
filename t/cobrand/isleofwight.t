use utf8;
use CGI::Simple;
use DateTime;
use Test::MockModule;
use FixMyStreet::TestMech;
use Open311;
use Open311::GetServiceRequests;
use Open311::GetServiceRequestUpdates;
use Open311::PostServiceRequestUpdates;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::IsleOfWight');
$cobrand->mock('lookup_site_code', sub {
    my ($self, $row) = @_;
    return "Road ID" if $row->latitude == 50.7108;
});

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};
my $isleofwight = $mech->create_body_ok(2636, 'Isle of Wight Council', $params);
my $contact = $mech->create_contact_ok(
    body_id => $isleofwight->id,
    category => 'Potholes',
    email => 'pothole@example.org',
);
$contact->set_extra_fields( ( {
    code => 'urgent',
    datatype => 'string',
    description => 'question',
    variable => 'true',
    required => 'false',
    order => 1,
    datatype_description => 'datatype',
} ) );
$contact->update;

my $user = $mech->create_user_ok('user@example.org', name => 'Test User');
my $iow_user = $mech->create_user_ok('iow_user@example.org', name => 'IoW User', from_body => $isleofwight);
$iow_user->user_body_permissions->create({
    body => $isleofwight,
    permission_type => 'moderate',
});

my $contact2 = $mech->create_contact_ok(
    body_id => $isleofwight->id,
    category => 'Roads',
    email => 'roads@example.org',
    send_method => 'Triage',
);

my $admin_user = $mech->create_user_ok('admin-user@example.org', name => 'Admin User', from_body => $isleofwight);

$admin_user->user_body_permissions->create({
    body => $isleofwight,
    permission_type => 'triage'
});

my @reports = $mech->create_problems_for_body(1, $isleofwight->id, 'An Isle of wight report', {
    confirmed => '2019-10-25 09:00',
    lastupdate => '2019-10-25 09:00',
    latitude => 50.7108,
    longitude => -1.29573,
    user => $user,
    external_id => 101202303
});

subtest "check clicking all reports link" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'isleofwight',
    }, sub {
        $mech->get_ok('/');
        $mech->follow_link_ok({ text => 'All reports' });
    };

    $mech->content_contains("An Isle of wight report", "Isle of Wight report there");
    $mech->content_contains("Island Roads", "is still on cobrand");
};

subtest "use external id for reference number" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'isleofwight',
    }, sub {
        $mech->get_ok('/report/' . $reports[0]->id);
    };

    $mech->content_contains("101202303", "Display external id as reference number");
};

subtest "only original reporter can comment" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'isleofwight',
        COBRAND_FEATURES => { updates_allowed => { isleofwight => 'reporter' } },
    }, sub {
        $mech->get_ok('/report/' . $reports[0]->id);
        $mech->content_contains('Only the original reporter may leave updates');

        $mech->log_in_ok('user@example.org');
        $mech->get_ok('/report/' . $reports[0]->id);
        $mech->content_lacks('Only the original reporter may leave updates');
    };
};

subtest "check moderation label uses correct name" => sub {
    my $REPORT_URL = '/report/' . $reports[0]->id;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['isleofwight'],
    }, sub {
        $mech->log_out_ok;
        $mech->log_in_ok( $iow_user->email );
        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('show-moderation');
        $mech->follow_link_ok({ text_regex => qr/^Moderate$/ });
        $mech->content_contains('show-moderation');
        $mech->submit_form_ok({ with_fields => {
            problem_title  => 'Good good',
            problem_detail => 'Good good improved',
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );
        $mech->content_like(qr/Moderated by Island Roads/);
    };
};

subtest "front page summary uses report category not title" => sub {
    my $category = $reports[0]->category;
    ok $category, "category is not blank";
    my $title = $reports[0]->title;
    ok $title, "title is not blank";
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['isleofwight'],
    }, sub {
        $mech->log_out_ok;
        $mech->get_ok('/');
        $mech->content_like( qr/item-list__heading">$category/ );
        $mech->content_unlike( qr/item-list__heading">$title/ );
    };
};

$_->delete for @reports;

my $system_user = $mech->create_user_ok('system_user@example.org');

for my $status ( qw/ CLOSED FIXED DUPLICATE NOT_COUNCILS_RESPONSIBILITY NO_FURTHER_ACTION / ) {
    subtest "updates which mark report as $status close it to comments" => sub {
        my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
        my ($p) = $mech->create_problems_for_body(1, $isleofwight->id, '', { lastupdate => $dt });
        $p->update({ external_id => $p->id });

        my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
        <service_requests_updates>
        <request_update>
        <update_id>UPDATE_ID</update_id>
        <service_request_id>SERVICE_ID</service_request_id>
        <service_request_id_ext>ID_EXTERNAL</service_request_id_ext>
        <status>STATUS</status>
        <description>This is a note</description>
        <updated_datetime>UPDATED_DATETIME</updated_datetime>
        </request_update>
        </service_requests_updates>
        };

        my $update_dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new);

        $requests_xml =~ s/STATUS/$status/;
        $requests_xml =~ s/UPDATE_ID/@{[$p->id]}/;
        $requests_xml =~ s/SERVICE_ID/@{[$p->id]}/;
        $requests_xml =~ s/ID_EXTERNAL/@{[$p->id]}/;
        $requests_xml =~ s/UPDATED_DATETIME/$update_dt/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $system_user,
            current_open311 => $o,
            current_body => $isleofwight,
        );
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'isleofwight',
        }, sub {
            $update->process_body;
        };

        $mech->log_in_ok('user@example.org');
        $mech->get_ok('/report/' . $p->id);
        $mech->content_lacks('Provide an update', "No update form on report");

        $p->discard_changes;
        is $p->get_extra_metadata('closed_updates'), 1, "report closed to updates";
        $p->comments->delete;
        $p->delete;
    };
}

subtest "fetched requests do not use the description text" => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests>
    <request>
    <service_request_id>638344</service_request_id>
    <status>open</status>
    <status_notes>This is a note.</status_notes>
    <service_name>Potholes</service_name>
    <service_code>potholes\@example.org</service_code>
    <description>This the description of a pothole problem</description>
    <agency_responsible></agency_responsible>
    <service_notice></service_notice>
    <requested_datetime>DATETIME</requested_datetime>
    <updated_datetime>DATETIME</updated_datetime>
    <expected_datetime>DATETIME</expected_datetime>
    <lat>50.71086</lat>
    <long>-1.29573</long>
    </request>
    </service_requests>
    };

    my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
    $requests_xml =~ s/DATETIME/$dt/gm;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'requests.xml' => $requests_xml } );

    my $update = Open311::GetServiceRequests->new(
        system_user => $iow_user,
    );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'isleofwight',
    }, sub {
        $update->create_problems( $o, $isleofwight );
    };

    my $p = FixMyStreet::DB->resultset('Problem')->search(
                { external_id => 638344 }
            )->first;

    ok $p, 'Found problem';
    is $p->title, 'Potholes problem', 'correct problem title';
    is $p->detail, 'Potholes problem', 'correct problem description';
    $p->delete;
};

subtest "fixing passes along the correct message" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'isleofwight',
    }, sub {
        my $test_res = HTTP::Response->new();
        $test_res->code(200);
        $test_res->message('OK');
        $test_res->content('<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>');

        my $o = Open311->new(
            fixmystreet_body => $isleofwight,
            test_mode => 1,
            test_get_returns => { 'servicerequestupdates.xml' => $test_res },
        );

        my ($p) = $mech->create_problems_for_body(1, $isleofwight->id, 'Title', { external_id => 1 });

        my $c = FixMyStreet::DB->resultset('Comment')->create({
            problem => $p, user => $p->user, anonymous => 't', text => 'Update text',
            problem_state => 'fixed - council', state => 'confirmed', mark_fixed => 0,
            confirmed => DateTime->now(),
        });

        my $id = $o->post_service_request_update($c);
        is $id, 248, 'correct update ID returned';
        my $cgi = CGI::Simple->new($o->test_req_used->content);
        like $cgi->param('description'), qr/^FMS-Update:/, 'FMS update prefix included';
        unlike $cgi->param('description'), qr/The customer indicated that this issue had been fixed/, 'No fixed message included';

        $c = $mech->create_comment_for_problem($p, $p->user, 'Name', 'Update text', 'f', 'confirmed', 'fixed - user');
        $c->discard_changes; # Otherwise cannot set_nanosecond

        $id = $o->post_service_request_update($c);
        is $id, 248, 'correct update ID returned';
        $cgi = CGI::Simple->new($o->test_req_used->content);
        like $cgi->param('description'), qr/^FMS-Update: \[The customer indicated that this issue had been fixed/, 'Fixed message included';
        $p->comments->delete;
        $p->delete;
    };
};

subtest 'Check special Open311 request handling', sub {
    $mech->clear_emails_ok;
    my ($p) = $mech->create_problems_for_body(1, $isleofwight->id, 'Title', { category => 'Potholes', latitude => 50.7108, longitude => -1.29573, cobrand => 'isleofwight' });
    $p->set_extra_fields({ name => 'urgent', value => 'no'});
    $p->update;

    my $test_data;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => ['isleofwight' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $test_data = FixMyStreet::Script::Reports::send();
    };

    $p->discard_changes;
    ok $p->whensent, 'Report marked as sent';
    is $p->send_method_used, 'Open311', 'Report sent via Open311';
    is $p->external_id, 248, 'Report has right external ID';

    my $req = $test_data->{test_req_used};
    my $c = CGI::Simple->new($req->content);
    is $c->param('attribute[urgent]'), undef, 'no urgent param sent';
    is $c->param('attribute[site_code]'), 'Road ID', 'road ID set';

    $mech->email_count_is(1);
    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email),
        qr/your enquiry has been received by Island Roads/, "correct report send email text";
};

subtest "comment recording triage details is not sent" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => [ 'isleofwight' ],
    }, sub {
        my $test_res = HTTP::Response->new();
        $test_res->code(200);
        $test_res->message('OK');
        $test_res->content('<?xml version="1.0" encoding="utf-8"?><service_request_updates></service_request_updates>');

        my $o = Open311->new(
            fixmystreet_body => $isleofwight,
            test_mode => 1,
            test_get_returns => { 'servicerequestupdates.xml' => $test_res },
        );

        my ($p) = $mech->create_problems_for_body(
            1, $isleofwight->id, 'Title',
            {
                category => 'Roads',
                areas => 2636,
                latitude => 50.71086,
                longitude => -1.29573,
                whensent => DateTime->now->add( minutes => -5 ),
                send_method_used => 'Triage',
                state => 'for triage',
                external_id => 1,
            });

        $mech->log_out_ok;
        $mech->log_in_ok($admin_user->email);
        my $report_url = '/report/' . $p->id;
        $mech->get_ok($report_url);
        $mech->submit_form_ok( {
                with_fields => {
                    category => 'Potholes',
                    include_update => 0,
                }
            },
            'triage form submitted'
        );

        ok $p->comments->first, 'comment created for problem';

        $p->update({
            send_method_used => 'Open311',
            whensent => DateTime->now->add( minutes => -5 ),
        });

        my $updates = Open311::PostServiceRequestUpdates->new(
            current_open311 => $o,
        );
        my $id = $updates->process_body($isleofwight);
        ok !$o->test_req_used, 'no open311 update sent';

        $p->comments->delete;
        $p->delete;
    };
};

my ($p) = $mech->create_problems_for_body(1, $isleofwight->id, '', { cobrand => 'isleofwight' });
my $alert = FixMyStreet::DB->resultset('Alert')->create( {
    parameter  => $p->id,
    alert_type => 'new_updates',
    user       => $user,
    cobrand    => 'isleofwight',
} )->confirm;

subtest "sends branded alert emails" => sub {
    $mech->create_comment_for_problem($p, $system_user, 'Other User', 'This is some update text', 'f', 'confirmed', undef);
    $mech->clear_emails_ok;

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['isleofwight','fixmystreet'],
    }, sub {
        FixMyStreet::Script::Alerts::send();
    };

    $mech->email_count_is(1);
    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email), qr/Island Roads/, "emails are branded";
};

$p->comments->delete;
$p->delete;

subtest "check not responsible as correct text" => sub {
    my ($p) = $mech->create_problems_for_body(
        1, $isleofwight->id, 'Title',
        {
            category => 'Roads',
            areas => 2636,
            latitude => 50.71086,
            longitude => -1.29573,
            whensent => DateTime->now->add( minutes => -5 ),
            send_method_used => 'Open311',
            state => 'not responsible',
            external_id => 1,
        });

    my $c = FixMyStreet::DB->resultset('Comment')->create({
        problem => $p, user => $p->user, anonymous => 't', text => 'Update text',
        problem_state => 'not responsible', state => 'confirmed', mark_fixed => 0,
        confirmed => DateTime->now(),
    });
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['isleofwight'],
    }, sub {
        $mech->get_ok('/report/' . $p->id);
    };

    $mech->content_contains("not Island Roads’ responsibility", "not reponsible message contains correct text");
    $p->comments->delete;
    $p->delete;
};

subtest "sends branded confirmation emails" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'isleofwight' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'PO30 5XJ', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    username      => 'test-1@example.com',
                    category      => 'Roads',
                }
            },
            "submit good details"
        );

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
        like $mech->get_text_body_from_email($email), qr/Island Roads/, "emails are branded";

        my $url = $mech->get_link_from_email($email);
        $mech->get_ok($url);
        $mech->clear_emails_ok;
    };
};

subtest "sends branded report sent emails" => sub {
    $mech->clear_emails_ok;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['isleofwight','fixmystreet'],
    }, sub {
        FixMyStreet::Script::Reports::send();
    };
    $mech->email_count_is(1);
    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email), qr/Island Roads/, "emails are branded";
};

subtest "check category extra uses correct name" => sub {
    my @extras = ( {
            code => 'test',
            datatype => 'string',
            description => 'question',
            variable => 'true',
            required => 'false',
            order => 1,
            datatype_description => 'datatype',
        } );
    $contact2->set_extra_fields( @extras );
    $contact2->update;

    my $extra_details;

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['isleofwight','fixmystreet'],
    }, sub {
        $extra_details = $mech->get_ok_json('/report/new/category_extras?category=Roads&latitude=50.71086&longitude=-1.29573');
    };

    like $extra_details->{category_extra}, qr/Island Roads/, 'correct name in category extras';
};

subtest "reports are marked for triage upon submission" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;
    $mech->log_in_ok($user->email);
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
        ALLOWED_COBRANDS => [ 'isleofwight' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'PO30 5XJ', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    category      => 'Roads',
                }
            },
            "submit good details"
        );

        my $report = $user->problems->first;
        ok $report, "Found the report";
        is $report->state, 'confirmed', 'report confirmed';

        $mech->clear_emails_ok;

        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        is $report->state, 'for triage', 'report marked as for triage';
        ok $report->whensent, 'report marked as sent';

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        like $mech->get_text_body_from_email($email),
            qr/submitted to Island Roads for review/, 'correct text for email sent for Triage';
    };
};

for my $cobrand ( 'fixmystreet', 'isleofwight' ) {
    subtest "only categories for Triage are displayed on " . $cobrand => sub {
        $mech->log_out_ok;
        $mech->get_ok('/around');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ $cobrand ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'PO30 5XJ', } },
                "submit location" );

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            my $f = $mech->form_name('mapSkippedForm');
            ok $f, 'found form';
            my $cats = $f->find_input('category');
            ok $cats, 'found category element';
            my @values = $cats->possible_values;
            is_deeply \@values, [ '-- Pick a category --', 'Roads' ], 'correct category list';
        };
    };

    subtest "staff user can see non Triage categories on " . $cobrand => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($admin_user->email);
        $mech->get_ok('/around');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ $cobrand ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'PO30 5XJ', } },
                "submit location" );

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            my $f = $mech->form_name('mapSkippedForm');
            ok $f, 'found form';
            my $cats = $f->find_input('category');
            ok $cats, 'found category element';
            my @values = $cats->possible_values;
            is_deeply \@values, [ '-- Pick a category --', 'Potholes' ], 'correct category list';
        };
    };
}

done_testing();
