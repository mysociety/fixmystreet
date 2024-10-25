use CGI::Simple;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok( 21069, 'Cheshire East Council', {
    send_method => 'Open311',
    endpoint => 'endpoint',
    api_key => 'key',
    jurisdiction => 'cheshireeast_confirm',
    cobrand => 'cheshireeast',
});

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Zebra Crossing',
    email => 'ZEBRA',
);

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::CheshireEast');
$cobrand->mock('_fetch_features', sub {
    return [];
});

my $staff_user = $mech->create_user_ok('astaffuser@example.com', name => 'A staff user', from_body => $body);

use_ok 'FixMyStreet::Cobrand::CheshireEast';

FixMyStreet::override_config {
    COBRAND_FEATURES => {
        contact_email => {
            cheshireeast => 'foo@cheshireeast',
        }
    },
}, sub {
    my $cobrand = FixMyStreet::Cobrand::CheshireEast->new;
    like $cobrand->contact_email, qr/cheshireeast/;
    is_deeply $cobrand->disambiguate_location->{bounds}, [ 52.947150, -2.752929, 53.387445, -1.974789 ];
};

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    category => 'Zebra Crossing',
    photo => '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg,74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg',
    extra => {
        contributed_as => 'another_user',
        contributed_by => $staff_user->id,
    },
});
my $report = $reports[0];

my $alert = FixMyStreet::DB->resultset("Alert")->create({
    alert_type => 'new_updates',
    cobrand => 'cheshireeast',
    parameter => $report->id,
    user => {
        email => 'alert@example.com',
        email_verified => 1,
    },
});
$alert->confirm;

$mech->create_comment_for_problem($report, $report->user, $report->name, 'blah', 0, 'confirmed', 'confirmed', {
    confirmed => \'current_timestamp'
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'cheshireeast',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { skip_checks => 1, send_reports => 1 },
}, sub {

    subtest 'cobrand displays council name' => sub {
        ok $mech->host("cheshireeast.fixmystreet.com"), "change host to cheshireeast";
        $mech->get_ok('/');
        $mech->content_contains('Cheshire East');
    };

    subtest 'testing special Open311 behaviour', sub {
        my $data = {
            display_name => 'Constitution Hill, London',
            address => {
                road => 'Constitution Hill',
                city => 'London',
            }
        };
        $report->geocode($data);
        $report->update;

        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        ok $report->whensent, 'Report marked as sent';
        is $report->send_method_used, 'Open311', 'Report sent via Open311';
        is $report->external_id, 248, 'Report has right external ID';
        is $report->detail, 'Test Test 1 for ' . $body->id . ' Detail', 'Report detail is unchanged';

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[title]'), 'Test Test 1 for ' . $body->id, 'Request had correct title';
        my $expected_desc = 'Test Test 1 for ' . $body->id . " Detail\n\n(this report was made by <" . $staff_user->email . "> (" . $staff_user->name .") on behalf of the user)";
        (my $c_description = $c->param('attribute[description]')) =~ s/\r\n/\n/g;
        is $c_description, $expected_desc, 'Request had correct description attribute';
        ($c_description = $c->param('description')) =~ s/\r\n/\n/g;
        is $c_description, "Test Test 1 for " . $body->id . "\n\n$expected_desc\n\nhttp://www.example.org/report/" . $report->id . "\n", 'Request had correct description';

        is_deeply [ $c->param('media_url') ], [
            'http://www.example.org/photo/' . $report->id . '.0.full.jpeg?74e33622',
            'http://www.example.org/photo/' . $report->id . '.1.full.jpeg?74e33622',
        ], 'Request had multiple photos';

        is $c->param('attribute[closest_address]'), 'Constitution Hill, London', 'closest address correctly set';
    };

    subtest 'testing reference numbers shown' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('Council ref:&nbsp;' . $report->id);
        FixMyStreet::Script::Alerts::send_updates();
        like $mech->get_text_body_from_email, qr/reference number is @{[$report->id]}/;
    };

    subtest 'contact page blocked', sub {
        $mech->get('/contact');
        is $mech->res->code, 404;
    };

    subtest 'check post-submission message', sub {
        $mech->log_in_ok($report->user->email);
        $mech->get_ok('/report/new?latitude=53.145324&longitude=-2.370437');
        $mech->submit_form_ok({ with_fields => {
            title => 'title',
            detail => 'detail',
        }});
        my $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        my $report_id = $report->id;
        $mech->content_contains('0300 123 5500');
        $mech->content_like(qr/quoting your reference number $report_id/);
    };

    subtest 'checking alert pages', sub {
        $mech->get_ok('/alert');
        $mech->content_contains('all reported problems');
        $mech->submit_form_ok({ with_fields => { pc => 'CW11 1HZ' } });
        $mech->content_contains('Reported problems within 10.0km');
        $mech->content_contains('All reported problems');
        $mech->content_contains('Reported problems within Sandbach Town');
    };

    $mech->delete_problems_for_body($body->id);
    my $admin_user = $mech->create_user_ok('adminuser@example.com', name => 'An admin user', from_body => $body, is_superuser => 1);
    my $staff1_user = $mech->create_user_ok('staff1@example.com', name => 'Staff One', from_body => $body);
    my $staff2_user = $mech->create_user_ok('staff2@example.com', name => 'Staff Two', from_body => $body);
    my $staff3_user = $mech->create_user_ok('staff3@example.com', name => 'Staff Three', from_body => $body);
    my $staff1_user_id = $staff1_user->id;
    my $staff1_user_name = $staff1_user->name;
    my $staff2_user_id = $staff2_user->id;
    my $staff2_user_name = $staff2_user->name;
    my $staff3_user_id = $staff3_user->id;
    my $staff3_user_name = $staff3_user->name;

    my @new_reports = $mech->create_problems_for_body( 4, $body->id, 'Assignee', {
        category => 'Zebra Crossing',
        extra => {
            contributed_as => 'another_user',
            contributed_by => $staff_user->id,
        },
    });

    subtest 'checking assignee filter on admin/reports page', sub {
        $mech->log_in_ok($admin_user->email);

        $mech->get_ok('/admin/reports');
        my $header_count = my @headers = $mech->content =~ /<th>/g;
        is $header_count, 7, "Additional column in header";
        $mech->content_contains('Assignee</option>');
        $mech->content_lacks("<option value=\"$staff1_user_id\">$staff1_user_name</option>");
        $mech->content_lacks("<option value=\"$staff2_user_id\">$staff2_user_name</option>");
        $mech->content_lacks("<option value=\"$staff3_user_id\">$staff3_user_name</option>");
        $mech->content_contains("<td>" . $new_reports[0]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[1]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[2]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[3]->title. "</td>");

        $staff1_user->add_to_planned_reports($new_reports[0]);
        $staff1_user->add_to_planned_reports($new_reports[2]);
        $staff2_user->add_to_planned_reports($new_reports[1]);

        $mech->get_ok('/admin/reports');
        $mech->content_contains("<option value=\"$staff1_user_id\">$staff1_user_name</option>");
        $mech->content_contains("<option value=\"$staff2_user_id\">$staff2_user_name</option>");
        $mech->content_lacks("<option value=\"$staff3_user_id\">$staff3_user_name</option>");
        $mech->content_contains("<td>" . $new_reports[0]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[1]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[2]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[3]->title. "</td>");
        $mech->submit_form_ok( { with_fields => {
            'assignee' => $staff1_user->id,
        }});
        $mech->content_contains("<td>" . $new_reports[0]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[2]->title. "</td>");
        $mech->content_lacks("<td>" . $new_reports[1]->title. "</td>");
        $mech->content_lacks("<td>" . $new_reports[3]->title. "</td>");
        $mech->submit_form_ok( { with_fields => {
            'assignee' => $staff2_user->id,
        }});
        $mech->content_lacks("<td>" . $new_reports[0]->title. "</td>");
        $mech->content_lacks("<td>" . $new_reports[2]->title. "</td>");
        $mech->content_lacks("<td>" . $new_reports[3]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[1]->title. "</td>");
        $mech->submit_form_ok( { with_fields => {
            'assignee' => 'Unassigned',
        }});
        $mech->content_lacks("<td>" . $new_reports[0]->title. "</td>");
        $mech->content_lacks("<td>" . $new_reports[2]->title. "</td>");
        $mech->content_lacks("<td>" . $new_reports[1]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[3]->title. "</td>");
        $mech->submit_form_ok( { with_fields => {
            'assignee' => 'All',
        }});
        $mech->content_contains("<td>" . $new_reports[0]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[1]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[2]->title. "</td>");
        $mech->content_contains("<td>" . $new_reports[3]->title. "</td>");
    };
};

done_testing();
