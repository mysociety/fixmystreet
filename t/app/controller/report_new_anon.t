package FixMyStreet::Cobrand::AnonAllowed;
use parent 'FixMyStreet::Cobrand::FixMyStreet';
sub allow_anonymous_reports { 1 }
sub anonymous_account { { email => 'anon@example.org', name => 'Anonymous' } }

package FixMyStreet::Cobrand::AnonAllowedByButton;
use parent 'FixMyStreet::Cobrand::FixMyStreet';
sub allow_anonymous_reports { 'button' }
sub anonymous_account { { email => 'anonbutton@example.org', name => 'Anonymous Button' } }

package main;

use FixMyStreet::TestMech;
use FixMyStreet::App;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2651, 'Edinburgh');
my $contact1 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street lighting',
    email => 'highways@example.com',
);
my $contact2 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Trees',
    email => 'trees@example.com',
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'anonallowed',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

subtest "check form errors when anonymous account is on" => sub {
    $mech->get_ok('/around');

    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok( { with_fields => { category => "Street lighting" } }, "submit form" );

    my @errors = (
        'Please enter a subject',
        'Please enter some details',
        # No user errors
    );
    is_deeply [ sort @{$mech->page_errors} ], [ sort @errors ], "check errors";
};

subtest "test report creation anonymously" => sub {
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            button => 'submit_register',
            with_fields => {
                title => 'Test Report',
                detail => 'Test report details.',
                name => 'Joe Bloggs',
                may_show_name => '1',
                category => 'Street lighting',
            }
        },
        "submit good details"
    );
    $mech->content_contains('Thank you');

    is_deeply $mech->page_errors, [], "check there were no errors";

    my $report = FixMyStreet::DB->resultset("Problem")->first;
    ok $report, "Found the report";

    is $report->state, 'confirmed', "report confirmed";
    $mech->get_ok( '/report/' . $report->id );

    is $report->bodies_str, $body->id;
    is $report->name, 'Anonymous';
    is $report->anonymous, 0; # Doesn't change behaviour here, but uses anon account's name always

    my $alert = FixMyStreet::App->model('DB::Alert')->find( {
        user => $report->user,
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    is $alert, undef, "no alert created";

    $mech->not_logged_in_ok;
};

};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'anonallowedbybutton',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

subtest "test report creation anonymously by button" => sub {
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            button => 'submit_register',
            with_fields => {
                title => 'Test Report',
                detail => 'Test report details.',
                name => 'Joe Bloggs',
                may_show_name => '1',
                category => 'Street lighting',
            }
        },
        "submit good details"
    );

    is_deeply $mech->page_errors, [
        'Please enter your email'
    ], "check there were no errors";

    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            button => 'report_anonymously',
            with_fields => {
                title => 'Test Report',
                detail => 'Test report details.',
                category => 'Street lighting',
            }
        },
        "submit good details"
    );
    $mech->content_contains('Thank you');

    is_deeply $mech->page_errors, [], "check there were no errors";

    my $report = FixMyStreet::DB->resultset("Problem")->search({}, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";

    is $report->state, 'confirmed', "report confirmed";
    $mech->get_ok( '/report/' . $report->id );

    is $report->bodies_str, $body->id;
    is $report->name, 'Anonymous Button';
    is $report->anonymous, 1; # Doesn't change behaviour here, but uses anon account's name always

    my $alert = FixMyStreet::App->model('DB::Alert')->find( {
        user => $report->user,
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    is $alert, undef, "no alert created";

    $mech->not_logged_in_ok;
};

};

done_testing();
