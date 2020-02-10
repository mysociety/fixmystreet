use FixMyStreet::TestMech;
use FixMyStreet::App;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Questionnaires;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');


my $body = $mech->create_body_ok(2482, 'TfL');
FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 2483, # Hounslow
    body_id => $body->id,
});
FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 2457, # Epsom Ewell, outside London, for bus stop test
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
$mech->create_contact_ok(
    body_id => $bromley->id,
    category => 'Accumulated Litter',
    email => 'litter-bromley@example.com',
);
my $bromley_flooding = $mech->create_contact_ok(
    body_id => $bromley->id,
    category => 'Flooding (Bromley)',
    email => 'litter-bromley@example.com',
);
$bromley_flooding->set_extra_metadata(display_name => 'Flooding');
$bromley_flooding->update;

my $bromley_flytipping = $mech->create_contact_ok(
    body_id => $bromley->id,
    category => 'Flytipping (Bromley)',
    email => 'flytipping-bromley@example.com',
);
$bromley_flytipping->set_extra_metadata(group => [ 'Street cleaning' ]);
$bromley_flytipping->update;

my $contact1 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Bus stops',
    email => 'busstops@example.com',
);
$contact1->set_extra_metadata(group => [ 'Bus things' ]);
$contact1->set_extra_fields(
    {
        code => 'leaning',
        description => 'Is the pole leaning?',
        datatype => 'string',
    },
    {
        code => 'stop_code',
        description => 'Stop number',
        datatype => 'string',
        automated => 'hidden_field',
    }
);
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
my $contact2b = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Timings',
    email => 'trafficlighttimings@example.com',
);

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
        base_url => {
            tfl => 'https://street.tfl'
        },
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
        anonymous_account => {
            tfl => 'anonymous'
        },
        contact_name => {
            tfl => 'TfL Street Care',
        },
        do_not_reply_email => {
            tfl => 'fms-tfl-DO-NOT-REPLY@example.com',
        },
        send_questionnaire => {
            fixmystreet => {
                TfL => 0,
            }
        },
    },
}, sub {

$mech->host("tfl.fixmystreet.com");

subtest "test report creation anonymously by button" => sub {
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'BR1 3UH', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            button => 'report_anonymously',
            with_fields => {
                title => 'Anonymous Test Report 1',
                detail => 'Test report details.',
                category => 'Bus stops',
            }
        },
        "submit report anonymously"
    );
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Anonymous Test Report 1'});
    ok $report, "Found the report";

    $mech->content_contains('Your issue is on its way to Transport for London');
    $mech->content_contains('Your reference for this report is FMS' . $report->id) or diag $mech->content;

    is_deeply $mech->page_errors, [], "check there were no errors";

    is $report->state, 'confirmed', "report confirmed";
    $mech->get_ok( '/report/' . $report->id );

    is $report->bodies_str, $body->id;
    is $report->name, 'Anonymous user';
    is $report->user->email, 'anonymous@tfl.gov.uk';
    is $report->anonymous, 1; # Doesn't change behaviour here, but uses anon account's name always
    is $report->get_extra_metadata('contributed_as'), 'anonymous_user';

    my $alert = FixMyStreet::App->model('DB::Alert')->find( {
        user => $report->user,
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    is $alert, undef, "no alert created";

    $mech->not_logged_in_ok;
};

subtest "test report creation anonymously by staff user" => sub {
    $mech->clear_emails_ok;
    $mech->log_in_ok( $staffuser->email );
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'BR1 3UH', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            button => 'report_anonymously',
            with_fields => {
                title => 'Anonymous Test Report 2',
                detail => 'Test report details.',
                category => 'Bus stops',
            }
        },
        "submit report"
    );
    is_deeply $mech->page_errors, [], "check there were no errors";

    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Anonymous Test Report 2'});
    ok $report, "Found the report";

    $mech->content_contains('Your issue is on its way to Transport for London');
    $mech->content_contains('Your reference for this report is FMS' . $report->id) or diag $mech->content;

    is $report->state, 'confirmed', "report confirmed";
    $mech->get_ok( '/report/' . $report->id );

    $report->update({ state => 'fixed - council' });
    my $json = $mech->get_ok_json('/around/nearby?latitude=' . $report->latitude . '&longitude=' . $report->longitude);
    is @{$json->{pins}}, 2, 'right number of pins';

    is $report->bodies_str, $body->id;
    is $report->name, 'Anonymous user';
    is $report->user->email, 'anonymous@tfl.gov.uk';
    is $report->anonymous, 1;
    is $report->get_extra_metadata('contributed_as'), 'anonymous_user';

    my $alerts = FixMyStreet::App->model('DB::Alert')->search( {
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    is $alerts->count, 0, "no alerts created";
    ok $mech->email_count_is(0), "no emails sent";

    $mech->log_out_ok;
};

FixMyStreet::DB->resultset("Problem")->delete_all;

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
};

subtest "test bus report creation outside London, .com" => sub {
    $mech->host('www.fixmystreet.com');
    $mech->get_ok('/report/new?latitude=51.345714&longitude=-0.227959');
    $mech->content_lacks('Bus things');
    $mech->host('tfl.fixmystreet.com');
};

subtest "test bus report creation outside London" => sub {
    $mech->get_ok('/report/new?latitude=51.345714&longitude=-0.227959');
    $mech->submit_form_ok(
        {
            with_fields => {
                # A bus stop in East Ewell
                latitude => 51.345714,
                longitude => -0.227959,
                title => 'Test outwith London',
                detail => 'Test report details.',
                name => 'Joe Bloggs',
                may_show_name => '1',
                category => 'Bus stops',
            }
        },
        "submit good details"
    );
    $mech->content_contains('Your issue is on its way to Transport for London');
    is_deeply $mech->page_errors, [], "check there were no errors";

    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test outwith London'});
    ok $report, "Found the report";
    is $report->state, 'confirmed', "report confirmed";
    is $report->bodies_str, $body->id;
    $report->delete;

    $mech->log_out_ok;
};

subtest "extra information included in email" => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    $report->set_extra_fields({ name => 'stop_code', value => '12345678' });
    $report->update;
    my $id = $report->id;

    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'TfL <busstops@example.com>';
    like $mech->get_text_body_from_email($email[0]), qr/Report reference: FMS$id/, "FMS-prefixed ID in TfL email";
    like $mech->get_text_body_from_email($email[0]), qr/Stop number: 12345678/, "Bus stop code in TfL email";
    is $email[1]->header('To'), $report->user->email;
    is $email[1]->header('From'), '"TfL Street Care" <fms-tfl-DO-NOT-REPLY@example.com>';
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

subtest 'Inspect form state choices' => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    my $id = $report->id;
    $mech->get_ok("/report/$id");
    $mech->content_lacks('for triage');
    $mech->content_lacks('action scheduled');
};

subtest "change category, report resent to new location" => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    my $id = $report->id;

    $mech->log_in_ok( $superuser->email );
    $mech->get_ok("/admin/report_edit/$id");
    $mech->content_lacks('Timings');
    $mech->submit_form_ok({ with_fields => { category => 'Traffic lights' } });

    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'TfL <trafficlights@example.com>';
    $mech->clear_emails_ok;

    $mech->log_out_ok;
};

for my $test (
    [ 'BR1 3UH', 'tfl.fixmystreet.com', 'Trees', 'TfL <bromley@example.com>', 'Bromley borough team', 'reference number is FMS' ],
    [ 'BR1 3UH', 'www.fixmystreet.com', 'Trees', 'TfL <bromley@example.com>', 'Bromley borough team', 'reference number is' ],
    [ 'BR1 3UH', 'bromley.fixmystreet.com', 'Trees', 'TfL <bromley@example.com>', 'Bromley borough team', '' ],
    [ 'TW7 5JN', 'tfl.fixmystreet.com', 'Trees', 'TfL <hounslow@example.com>', 'Hounslow borough team', 'reference number is FMS' ],
    [ 'TW7 5JN', 'www.fixmystreet.com', 'Trees', 'TfL <hounslow@example.com>', 'Hounslow borough team', 'reference number is' ],
    [ 'TW7 5JN', 'tfl.fixmystreet.com', 'Grit bins', 'TfL <hounslow@example.com>, TfL <gritbins@example.com>', 'Hounslow borough team and additional address', 'reference number is FMS' ],
    [ 'TW7 5JN', 'www.fixmystreet.com', 'Grit bins', 'TfL <hounslow@example.com>, TfL <gritbins@example.com>', 'Hounslow borough team and additional address', 'reference number is' ],
) {
    my ($postcode, $host, $category, $to, $name, $ref ) = @$test;
    subtest "test report is sent to $name on $host" => sub {
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
        like $email[0]->as_string, qr/iEYI87gX6Upb\+tKYzrSmN83pTnv606AOtahHTepSm/, 'Right logo';
        like $mech->get_text_body_from_email($email[0]), qr/https:\/\/street.tfl/, 'Correct link';
        like $mech->get_text_body_from_email($email[1]), qr/$ref/, "Correct reference number in reporter email" if $ref;
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

subtest 'check correct base URL & title in AJAX pins' => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    my $url = '/around?ajax=1&bbox=' . ($report->longitude - 0.01) . ',' .  ($report->latitude - 0.01)
        . ',' . ($report->longitude + 0.01) . ',' .  ($report->latitude + 0.01);

    $report->update({ state => 'confirmed' });
    $report->discard_changes;
    is $report->cobrand, 'tfl', 'Report made on TfL cobrand';

    $mech->host("fixmystreet.com");
    my $json = $mech->get_ok_json( $url );
    is $json->{pins}[0][4], $report->category . " problem", "category is used for title" or diag $mech->content;
    is $json->{pins}[0][7], "https://street.tfl", "base_url is included and correct" or diag $mech->content;

    $mech->host("tfl.fixmystreet.com");
    $json = $mech->get_ok_json( $url );
    is $json->{pins}[0][4], $report->title, "title is shown on TfL cobrand" or diag $mech->content;
    is $json->{pins}[0][7], undef, "base_url is not present on TfL cobrand response";

    $mech->host("fixmystreet.com");
    $report->update({cobrand => 'fixmystreet'});
    $json = $mech->get_ok_json( $url );
    is $json->{pins}[0][4], $report->title, "title is shown if report made on fixmystreet cobrand" or diag $mech->content;
    is $json->{pins}[0][7], undef, "base_url is not present if report made on fixmystreet cobrand";

    $report->update({cobrand => 'tfl'});
    $mech->host("tfl.fixmystreet.com");
};

subtest 'check report age on /around' => sub {
    $mech->log_in_ok($staffuser->email);
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    $report->update({ state => 'confirmed' });

    $mech->get_ok( '/around?lat=' . $report->latitude . '&lon=' . $report->longitude );
    $mech->content_contains($report->title);
    $mech->content_contains('item-list__item__borough">Bromley');

    $report->update({
        confirmed => \"current_timestamp-'7 weeks'::interval",
        whensent => \"current_timestamp-'7 weeks'::interval",
        lastupdate => \"current_timestamp-'7 weeks'::interval",
    });

    $mech->get_ok( '/around?lat=' . $report->latitude . '&lon=' . $report->longitude );
    $mech->content_lacks($report->title);

    $report->update({
        confirmed => \"current_timestamp",
        whensent => \"current_timestamp",
        lastupdate => \"current_timestamp",
    });
};

subtest 'check report age in general' => sub {
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    $report->update({ state => 'confirmed' });
    $mech->get_ok('/report/' . $report->id);
    $report->update({ lastupdate => \"current_timestamp-'4 years'::interval" });
    $mech->get('/report/' . $report->id);
    is $mech->res->code, 404;
    $report->update({ lastupdate => \"current_timestamp" });
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

my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
$report->update({ cobrand => 'fixmystreet' });
$staffuser->add_to_planned_reports($report);

for my $host ( 'www.fixmystreet.com', 'tfl.fixmystreet.com' ) {
    subtest "Leave an update on a shortlisted report on $host, get an email" => sub {
        $mech->host($host);
        $mech->log_in_ok( $user->email );
        $mech->get_ok('/report/' . $report->id);
        $mech->submit_form_ok({ with_fields => { update => 'This is an update' }});
        my $email = $mech->get_email;
        my $text = $mech->get_text_body_from_email;
        like $text, qr/This is an update/, 'Right email';
        like $text, qr/street.tfl/, 'Right url';
        like $text, qr/Street Care/, 'Right name';
        like $email->as_string, qr/iEYI87gX6Upb\+tKYzrSmN83pTnv606AOtahHTepSm/, 'Right logo';
    };
}

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

subtest 'Test passwords work appropriately' => sub {
    $mech->host('www.fixmystreet.com');
    $mech->get_ok('/auth');
    $user->password('dotcom');
    $user->update;
    $mech->submit_form_ok(
        { with_fields => { username => $user->email, password_sign_in => 'dotcom' } },
        "sign in using form" );
    $mech->content_contains('Your account');
    $mech->host('tfl.fixmystreet.com');
    $mech->get_ok('/auth');
    $mech->submit_form_ok(
        { with_fields => { username => $user->email, password_sign_in => 'dotcom' } },
        "sign in using form" );
    $mech->content_lacks('Your account');

    $user->password('tfl');
    $user->update;
    $mech->submit_form_ok(
        { with_fields => { username => $user->email, password_sign_in => 'tfl' } },
        "sign in using form" );
    $mech->content_contains('Your account');
    $mech->host('www.fixmystreet.com');
    $mech->get_ok('/auth');
    $mech->submit_form_ok(
        { with_fields => { username => $user->email, password_sign_in => 'tfl' } },
        "sign in using form" );
    $mech->content_lacks('Your account');
};

my $tfl_report;
subtest 'Test user reports are visible on cobrands appropriately' => sub {
    ($tfl_report) = $mech->create_problems_for_body(1, $body->id, 'Test TfL report made on TfL', { cobrand => 'tfl' });
    $mech->create_problems_for_body(1, $body->id, 'Test TfL report made on .com', { cobrand => 'fixmystreet' });
    $mech->create_problems_for_body(1, $bromley->id, 'Test Bromley report made on .com', { cobrand => 'fixmystreet' });

    $mech->log_in_ok('test@example.com');
    $mech->get_ok('/my');
    $mech->content_contains('1 to 2 of 2');
    $mech->content_contains('Test TfL report made on .com');
    $mech->content_lacks('Test TfL report made on TfL');
    $mech->content_contains('Test Bromley report');

    $mech->host('tfl.fixmystreet.com');
    $mech->log_in_ok('test@example.com');
    $mech->get_ok('/my');
    $mech->content_contains('1 to 2 of 2');
    $mech->content_contains('Test TfL report made on .com');
    $mech->content_contains('Test TfL report made on TfL');
    $mech->content_lacks('Test Bromley report');
};

subtest 'Test public reports are visible on cobrands appropriately' => sub {
    $mech->get_ok('/around?pc=SW1A+1AA');
    $mech->content_contains('Test TfL report made on .com');
    $mech->content_contains('Test TfL report made on TfL');
    $mech->content_lacks('Test Bromley report');

    $mech->host('www.fixmystreet.com');
    $mech->get_ok('/around?pc=SW1A+1AA');
    $mech->content_contains('Test TfL report made on .com');
    $mech->content_lacks('Test TfL report made on TfL');
    $mech->content_contains('Test Bromley report');
    $mech->content_contains('https://street.tfl/report/' . $tfl_report->id);
    $mech->content_contains('Other problem');
};

subtest 'Test no questionnaire sending' => sub {
    $report->update({ send_questionnaire => 1, whensent => \"current_timestamp-'7 weeks'::interval" });
    FixMyStreet::Script::Questionnaires::send();
    $mech->email_count_is(0);
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
        anonymous_account => {
            tfl => 'anonymous'
        },
        do_not_reply_email => {
            tfl => 'fms-tfl-DO-NOT-REPLY@example.com',
        },
    },
}, sub {

for my $test (
    {
        host => 'www.fixmystreet.com',
        name => "test red route categories",
        lat => 51.4039,
        lon => 0.018697,
        expected => [
            'Accumulated Litter', # Tests TfL->_cleaning_categories
            'Bus stops',
            'Flooding',
            'Flytipping (Bromley)', # In the 'Street cleaning' group
            'Grit bins',
            'Pothole',
            'Timings',
            'Traffic lights',
            'Trees'
        ],
    },
    {
        host => 'www.fixmystreet.com',
        name => "test non-red route categories",
        lat => 51.4021,
        lon => 0.01578,
        expected => [
            'Accumulated Litter', # Tests TfL->_cleaning_categories
            'Bus stops',
            'Flooding (Bromley)',
            'Flytipping (Bromley)', # In the 'Street cleaning' group
            'Grit bins',
            'Timings',
            'Traffic lights',
            'Trees'
        ],
    },
    {
        host => 'tfl.fixmystreet.com',
        name => "test red route categories",
        lat => 51.4039,
        lon => 0.018697,
        expected => [
            'Bus stops',
            'Flooding',
            'Grit bins',
            'Pothole',
            'Timings',
            'Traffic lights',
            'Trees'
        ],
    },
    {
        host => 'tfl.fixmystreet.com',
        name => "test non-red route categories",
        lat => 51.4021,
        lon => 0.01578,
        expected => [
            'Bus stops',
            'Flooding',
            'Grit bins',
            'Pothole',
            'Timings',
            'Traffic lights',
            'Trees'
        ],
    },
    {
        host => 'bromley.fixmystreet.com',
        name => "test red route categories",
        lat => 51.4039,
        lon => 0.018697,
        expected => [
            'Accumulated Litter',
            'Bus stops',
            'Flooding',
            'Flytipping (Bromley)',
            'Grit bins',
            'Pothole',
            'Timings',
            'Traffic lights',
            'Trees'
        ],
    },
    {
        host => 'bromley.fixmystreet.com',
        name => "test non-red route categories",
        lat => 51.4021,
        lon => 0.01578,
        expected => [
            'Accumulated Litter',
            'Bus stops',
            'Flooding (Bromley)',
            'Flytipping (Bromley)',
            'Grit bins',
            'Timings',
            'Traffic lights',
            'Trees'
        ],
    },
) {
    subtest $test->{name} . ' on ' . $test->{host} => sub {
        $mech->host($test->{host});
        my $resp = $mech->get_ok_json( '/report/new/ajax?latitude=' . $test->{lat} . '&longitude=' . $test->{lon} );
        my @actual = sort keys %{ $resp->{by_category} };
        is_deeply \@actual, $test->{expected};
    };
}

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
            pc => "BR1 3EF", # this is on a red route (according to Mock::MapIt and Mock::Tilma anyway)
        },
        {
            name => "test category extra field - safety critical",
            safety_critical => 'yes',
            category => "Flooding",
            extra_fields => {
                location => "carriageway",
            },
            subject => "Dangerous Flooding Report: Test Report",
            pc => "BR1 3EF", # this is on a red route (according to Mock::MapIt and Mock::Tilma anyway)
        },
        {
            name => "test category extra field - non-safety critical",
            safety_critical => 'no',
            category => "Flooding",
            extra_fields => {
                location => "footway",
            },
            subject => "Problem Report: Test Report",
            pc => "BR1 3EF", # this is on a red route (according to Mock::MapIt and Mock::Tilma anyway)
        },
    ) {
    subtest $test->{name} . ' on ' . $host => sub {
            $mech->log_in_ok( $user->email );
            $mech->host($host);
            $mech->get_ok('/around');
            my $pc = $test->{pc} || 'BR1 3UH';
            $mech->submit_form_ok( { with_fields => { pc => $pc, } }, "submit location ($pc)" );
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

    subtest 'RSS feed has correct name' => sub {
        $mech->get_ok('/rss/xsl');
        $mech->content_contains('RSS feed from the Street Care website');
        $mech->content_lacks('FixMyStreet');
        $mech->get_ok('/rss/problems');
        $mech->content_contains('New problems on Street Care');
        $mech->content_lacks('FixMyStreet');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/'
}, sub {
    foreach (qw(tfl.fixmystreet.com fixmystreet.com)) {
        $mech->host($_);
        my ($p) = $mech->create_problems_for_body(1, $body->id, 'NotResp');
        my $c = FixMyStreet::DB->resultset('Comment')->create({
            problem => $p, user => $p->user, anonymous => 't', text => 'Update text',
            problem_state => 'not responsible', state => 'confirmed', mark_fixed => 0,
            confirmed => DateTime->now(),
        });
        subtest "check not responsible as correct text on $_" => sub {
            $mech->get_ok('/report/' . $p->id);
            $mech->content_contains("not TfL’s responsibility", "not reponsible message contains correct text");
        };
        $p->comments->delete;
        $p->delete;
    }
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
