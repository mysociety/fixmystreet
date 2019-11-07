use FixMyStreet::TestMech;
use FixMyStreet::App;
use FixMyStreet::Script::Reports;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2482, 'TfL');
FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 2483, # Hounslow
    body_id => $body->id,
});
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body, password => 'password');
$staffuser->user_body_permissions->create({
    body => $body,
    permission_type => 'contribute_as_body',
});
$staffuser->user_body_permissions->create({
    body => $body,
    permission_type => 'default_to_body',
});
my $user = $mech->create_user_ok('londonresident@example.com');

my $bromley = $mech->create_body_ok(2482, 'Bromley');
my $bromleyuser = $mech->create_user_ok('bromleyuser@bromley.example.com', name => 'Bromley Staff', from_body => $bromley);


my $contact1 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Bus stops',
    email => 'busstops@example.com',
);
$contact1->set_extra_metadata(group => [ 'Bus things' ]);
$contact1->set_extra_fields({
    code => 'leaning',
    description => 'Is the pole leaning?',
    datatype => 'string',
});
$contact1->update;
my $contact2 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Traffic lights',
    email => 'trafficlights@example.com',
);
$contact2->set_extra_fields({
    code => "safety_critical",
    description => "Safety critical",
    automated => "hidden_field",
    order => 1,
    datatype => "singlevaluelist",
    values => [
        {
            name => "Yes",
            key => "yes"
        },
        {
            name => "No",
            key => "no"
        }
    ]
});
$contact2->update;
my $contact3 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Pothole',
    email => 'pothole@example.com',
);
$contact3->set_extra_fields({
    code => "safety_critical",
    description => "Safety critical",
    automated => "hidden_field",
    order => 1,
    datatype => "singlevaluelist",
    values => [
        {
            name => "Yes",
            key => "yes"
        },
        {
            name => "No",
            key => "no"
        }
    ]
});
$contact3->update;
my $contact4 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Flooding',
    email => 'flooding@example.com',
);
$contact4->set_extra_fields(
    {
        code => "safety_critical",
        description => "Safety critical",
        automated => "hidden_field",
        order => 1,
        datatype => "singlevaluelist",
        values => [
            {
                name => "Yes",
                key => "yes"
            },
            {
                name => "No",
                key => "no"
            }
        ]
    },
    {
        code => "location",
        description => "Where is the flooding?",
        variable => "true",
        order => 1,
        required => "true",
        datatype => "singlevaluelist",
        values => [
            {
                name => "Carriageway",
                key => "carriageway"
            },
            {
                name => "Footway",
                key => "footway"
            }
        ]
    }
);
$contact4->update;
my $contact5 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Trees',
    email => 'AOAT',
);
my $contact6 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Grit bins',
    email => 'AOAT,gritbins@example.com',
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'tfl', 'bromley', 'fixmystreet'],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        internal_ips => { tfl => [ '127.0.0.1' ] },
        borough_email_addresses => { tfl => {
            AOAT => [
                {
                    email => 'hounslow@example.com',
                    areas => [ 2483 ],
                },
                {
                    email => 'bromley@example.com',
                    areas => [ 2482 ],
                },
            ],
        } },
    },
}, sub {

$mech->host("tfl.fixmystreet.com");

subtest "test report creation and reference number" => sub {
    $mech->log_in_ok( $user->email );
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'BR1 3UH', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            with_fields => {
                title => 'Test Report 1',
                detail => 'Test report details.',
                name => 'Joe Bloggs',
                may_show_name => '1',
                category => 'Bus stops',
            }
        },
        "submit good details"
    );

    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    ok $report, "Found the report";

    $mech->content_contains('Your issue is on its way to Transport for London');
    $mech->content_contains('Your reference for this report is FMS' . $report->id) or diag $mech->content;

    is_deeply $mech->page_errors, [], "check there were no errors";

    is $report->state, 'confirmed', "report confirmed";

    is $report->bodies_str, $body->id;
    is $report->name, 'Joe Bloggs';

    $mech->log_out_ok;
};

subtest "reference number included in email" => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    my $id = $report->id;

    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'TfL <busstops@example.com>';
    like $mech->get_text_body_from_email($email[0]), qr/Report reference: FMS$id/, "FMS-prefixed ID in TfL email";
    is $email[1]->header('To'), $report->user->email;
    like $mech->get_text_body_from_email($email[1]), qr/report's reference number is FMS$id/, "FMS-prefixed ID in reporter email";
    $mech->clear_emails_ok;

    $mech->get_ok( '/report/' . $report->id );
    $mech->content_contains('FMS' . $report->id) or diag $mech->content;
};

subtest 'Dashboard CSV extra columns' => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    $report->set_extra_fields({ name => 'leaning', value => 'Yes' });
    $report->update;

    $mech->log_in_ok( $staffuser->email );
    $mech->get_ok('/dashboard?export=1&category=Bus+stops');
    $mech->content_contains('Category,Subcategory');
    $mech->content_contains('Query,Borough');
    $mech->content_contains(',"Safety critical","Delivered to","Closure email at","Reassigned at","Reassigned by","Is the pole leaning?"');
    $mech->content_contains('"Bus things","Bus stops"');
    $mech->content_contains('"BR1 3UH",Bromley,');
    $mech->content_contains(',,,no,busstops@example.com,,,,Yes');

    $report->set_extra_fields({ name => 'safety_critical', value => 'yes' });
    $report->anonymous(1);
    $report->update;
    my $dt = DateTime->now();
    FixMyStreet::DB->resultset("AdminLog")->create({
        action => 'category_change',
        whenedited => $dt,
        object_id => $report->id,
        object_type => 'problem',
        admin_user => $staffuser->name,
        user => $staffuser,
    });
    $mech->get_ok('/dashboard?export=1');
    $mech->content_contains('Query,Borough');
    $mech->content_contains(',"Safety critical","Delivered to","Closure email at","Reassigned at","Reassigned by"');
    $mech->content_contains('(anonymous ' . $report->id . ')');
    $mech->content_contains(',,,yes,busstops@example.com,,' . $dt . ',"Council User"');
};

subtest "change category, report resent to new location" => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    my $id = $report->id;

    $mech->log_in_ok( $superuser->email );
    $mech->get_ok("/admin/report_edit/$id");
    $mech->submit_form_ok({ with_fields => { category => 'Traffic lights' } });

    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'TfL <trafficlights@example.com>';
    $mech->clear_emails_ok;

    $mech->log_out_ok;
};

for my $test (
    [ 'BR1 3UH', 'tfl.fixmystreet.com', 'Trees', 'TfL <bromley@example.com>', 'Bromley borough team' ],
    [ 'BR1 3UH', 'www.fixmystreet.com', 'Trees', 'TfL <bromley@example.com>', 'Bromley borough team' ],
    [ 'BR1 3UH', 'bromley.fixmystreet.com', 'Trees', 'TfL <bromley@example.com>', 'Bromley borough team' ],
    [ 'TW7 5JN', 'tfl.fixmystreet.com', 'Trees', 'TfL <hounslow@example.com>', 'Hounslow borough team' ],
    [ 'TW7 5JN', 'www.fixmystreet.com', 'Trees', 'TfL <hounslow@example.com>', 'Hounslow borough team' ],
    [ 'TW7 5JN', 'tfl.fixmystreet.com', 'Grit bins', 'TfL <hounslow@example.com>, TfL <gritbins@example.com>', 'Hounslow borough team and additional address' ],
    [ 'TW7 5JN', 'www.fixmystreet.com', 'Grit bins', 'TfL <hounslow@example.com>, TfL <gritbins@example.com>', 'Hounslow borough team and additional address' ],
) {
    my ($postcode, $host, $category, $to, $name ) = @$test;
    subtest "test report is sent to $name" => sub {
        $mech->host($host);
        $mech->log_in_ok( $user->email );
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => $postcode, } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                with_fields => {
                    title => 'Test Report for borough team',
                    detail => 'Test report details.',
                    may_show_name => '1',
                    category => $category,
                    $host eq 'bromley.fixmystreet.com' ? (
                        fms_extra_title => 'DR',
                        first_name => "Joe",
                        last_name => "Bloggs",
                    ) : (
                        name => 'Joe Bloggs',
                    ),
                }
            },
            "submit good details"
        );

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @email = $mech->get_email;
        is $email[0]->header('To'), $to, 'Sent to correct address';
        $mech->clear_emails_ok;
        FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report for borough team'})->delete;
    };
}

$mech->host("tfl.fixmystreet.com");

subtest 'check lookup by reference' => sub {
    my $id = FixMyStreet::DB->resultset("Problem")->first->id;

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => 'FMS12345' } }, 'bad ref');
    $mech->content_contains('Searching found no reports');

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "FMS$id" } }, 'good FMS-prefixed ref');
    is $mech->uri->path, "/report/$id", "redirected to report page when using FMS-prefixed ref";

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "fms $id" } }, 'good FMS-prefixed with a space ref');
    is $mech->uri->path, "/report/$id", "redirected to report page when using FMS-prefixed ref";

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "$id" } }, 'good ref');
    is $mech->uri->path, "/report/$id", "redirected to report page when using non-prefixed ref";
};

for my $test (
    {
        states => [ 'confirmed' ],
        colour => 'red'
    },
    {
        states => ['action scheduled', 'in progress', 'investigating', 'planned'],
        colour => 'orange'
    },
    {
        states => [ FixMyStreet::DB::Result::Problem->fixed_states, FixMyStreet::DB::Result::Problem->closed_states ],
        colour => 'green'
    },
) {
    subtest 'check ' . $test->{colour} . ' pin states' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
        my $url = '/around?ajax=1&bbox=' . ($report->longitude - 0.01) . ',' .  ($report->latitude - 0.01)
            . ',' . ($report->longitude + 0.01) . ',' .  ($report->latitude + 0.01);

        for my $state ( @{ $test->{states} } ) {
            $report->update({ state => $state });
            my $json = $mech->get_ok_json( $url );
            my $colour = $json->{pins}[0][2];
            is $colour, $test->{colour}, 'correct ' . $test->{colour} . ' pin for state ' . $state;
        }
    };
}

subtest 'check report age on /around' => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    $report->update({ state => 'confirmed' });

    $mech->get_ok( '/around?lat=' . $report->latitude . '&lon=' . $report->longitude );
    $mech->content_contains($report->title);

    $report->update({
        confirmed => \"current_timestamp-'7 weeks'::interval",
        whensent => \"current_timestamp-'7 weeks'::interval",
        lastupdate => \"current_timestamp-'7 weeks'::interval",
    });

    $mech->get_ok( '/around?lat=' . $report->latitude . '&lon=' . $report->longitude );
    $mech->content_lacks($report->title);
};

subtest 'TfL admin allows inspectors to be assigned to borough areas' => sub {
    $mech->log_in_ok($superuser->email);

    $mech->get_ok("/admin/users/" . $staffuser->id) or diag $mech->content;

    $mech->submit_form_ok( { with_fields => {
        area_ids => [2482],
    } } );

    $staffuser->discard_changes;
    is_deeply $staffuser->area_ids, [2482], "User assigned to Bromley LBO area";

    $staffuser->update({ area_ids => undef}); # so login below doesn't break
};

subtest 'Leave an update on a shortlisted report, get an email' => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    $staffuser->add_to_planned_reports($report);
    $mech->log_in_ok( $user->email );
    $mech->get_ok('/report/' . $report->id);
    $mech->submit_form_ok({ with_fields => { update => 'This is an update' }});
    my $email = $mech->get_text_body_from_email;
    like $email, qr/This is an update/;
};

subtest 'TfL staff can access TfL admin' => sub {
    $mech->log_in_ok( $staffuser->email );
    $mech->get_ok('/admin');
    $mech->content_contains( 'This is the administration interface for' );
    $mech->log_out_ok;
};

subtest 'Bromley staff cannot access TfL admin' => sub {
    $mech->log_in_ok( $bromleyuser->email );
    ok $mech->get('/admin');
    is $mech->res->code, 403, "got 403";
    $mech->log_out_ok;
};

};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'tfl', 'bromley', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        internal_ips => { tfl => [ '127.0.0.1' ] },
        safety_critical_categories => { tfl => {
            Pothole => 1,
            Flooding => {
                location => [ "carriageway" ],
            },
        } },
    },
}, sub {

for my $host ( 'tfl.fixmystreet.com', 'www.fixmystreet.com', 'bromley.fixmystreet.com' ) {
    for my $test (
        {
            name => "test non-safety critical category",
            safety_critical => 'no',
            category => "Traffic lights",
            subject => "Problem Report: Test Report",
        },
        {
            name => "test safety critical category",
            safety_critical => 'yes',
            category => "Pothole",
            subject => "Dangerous Pothole Report: Test Report",
        },
        {
            name => "test category extra field - safety critical",
            safety_critical => 'yes',
            category => "Flooding",
            extra_fields => {
                location => "carriageway",
            },
            subject => "Dangerous Flooding Report: Test Report",
        },
        {
            name => "test category extra field - non-safety critical",
            safety_critical => 'no',
            category => "Flooding",
            extra_fields => {
                location => "footway",
            },
            subject => "Problem Report: Test Report",
        },
    ) {
    subtest $test->{name} . ' on ' . $host => sub {
            $mech->log_in_ok( $user->email );
            $mech->host($host);
            $mech->get_ok('/around');
            $mech->submit_form_ok( { with_fields => { pc => 'BR1 3UH', } }, "submit location" );
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
            $mech->submit_form_ok(
                {
                    with_fields => {
                        category => $test->{category}
                    },
                    button => 'submit_category_part_only',
                }
            );
            $mech->submit_form_ok(
                {
                    with_fields => {
                        title => 'Test Report',
                        detail => 'Test report details.',
                        may_show_name => '1',
                        category => $test->{category},
                        %{ $test->{extra_fields} || {} },
                        $host eq 'bromley.fixmystreet.com' ? (
                            fms_extra_title => 'DR',
                            first_name => "Joe",
                            last_name => "Bloggs",
                        ) : (
                            name => 'Joe Bloggs',
                        ),
                    }
                },
                "submit report form"
            );

            my $report = FixMyStreet::App->model('DB::Problem')->to_body( $body->id )->search(undef, {
                order_by => { -desc => 'id' },
            })->first;
            ok $report, "Found the report";

            is $report->get_extra_field_value('safety_critical'), $test->{safety_critical}, "safety critical flag set to " . $test->{safety_critical};

            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();
            my @email = $mech->get_email;
            is $email[0]->header('Subject'), $test->{subject};
            if ($test->{safety_critical} eq 'yes') {
                like $mech->get_text_body_from_email($email[0]), qr/This report is marked as safety critical./, "Safety critical message included in email body";
            }
            $mech->clear_emails_ok;


            $mech->log_out_ok;
        };
    }
}
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'tfl',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => { internal_ips => { tfl => [ '127.0.0.1' ] } },
}, sub {
    subtest 'On internal network, user not asked to sign up for 2FA' => sub {
        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $staffuser->email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_contains('Your account');
    };
    subtest 'On internal network, user with 2FA not asked to enter it' => sub {
        use Auth::GoogleAuth;
        my $auth = Auth::GoogleAuth->new;
        my $code = $auth->code;

        $staffuser->set_extra_metadata('2fa_secret', $auth->secret32);
        $staffuser->update;
        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $staffuser->email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_lacks('generate a two-factor code');
        $mech->content_contains('Your account');
    };
    subtest 'On internal network, cannot disable 2FA' => sub {
        $mech->get_ok('/auth/generate_token');
        $mech->content_contains('Change two-factor');
        $mech->content_lacks('Deactivate two-factor');
        $staffuser->unset_extra_metadata('2fa_secret');
        $staffuser->update;
    };
};
FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'tfl',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'On external network, user asked to sign up for 2FA' => sub {
        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $staffuser->email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_contains('requires two-factor authentication');
    };
    subtest 'On external network, user with 2FA asked to enter it' => sub {
        use Auth::GoogleAuth;
        my $auth = Auth::GoogleAuth->new;
        my $code = $auth->code;

        $staffuser->set_extra_metadata('2fa_secret', $auth->secret32);
        $staffuser->update;
        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $staffuser->email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_contains('Please generate a two-factor code');
        $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
    };
    subtest 'On external network, cannot disable 2FA' => sub {
        $mech->get_ok('/auth/generate_token');
        $mech->content_contains('Change two-factor');
        $mech->content_lacks('Deactivate two-factor');
        $staffuser->unset_extra_metadata('2fa_secret');
        $staffuser->update;
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bromley',
    MAPIT_URL => 'http://mapit.uk/'
}, sub {

subtest 'Bromley staff can access Bromley admin' => sub {
    $mech->log_in_ok( $bromleyuser->email );
    $mech->get_ok('/admin');
    $mech->content_contains( 'This is the administration interface for' );
    $mech->log_out_ok;
};

subtest 'TfL staff cannot access Bromley admin' => sub {
    $mech->log_in_ok( $staffuser->email );
    ok $mech->get('/admin');
    is $mech->res->code, 403, "got 403";
    $mech->log_out_ok;
};

};

done_testing();
