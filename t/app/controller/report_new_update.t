use Test::MockTime qw(:all);

use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $comment_user = $mech->create_user_ok('systemuser@example.org', name => 'Glos Council');
my $body = $mech->create_body_ok(2226, 'Gloucestershire County Council', {
    comment_user => $comment_user,
});

$mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'potholes@example.com',
);

my $user = $mech->log_in_ok('test-2@example.com');

subtest "test report creation with no initial auto-update" => sub {
    my $report = make_report();
    my $comment = FixMyStreet::DB->resultset('Comment')->count;
    is $comment, 0, 'No comments left';
    $report->delete;
};

my $template = FixMyStreet::DB->resultset("ResponseTemplate")->create({
    body => $body,
    state => 'confirmed',
    title => 'Initial email response',
    text => 'Thanks for your report. We will investigate within 5 working days.',
    auto_response => 1,
});
ok $template, 'Template created';

my $report;
subtest "test report creation with initial auto-update" => sub {
    $report = make_report();
    my $comment = FixMyStreet::DB->resultset('Comment')->single;
    is $comment->text, 'Thanks for your report. We will investigate within 5 working days.';
    is $comment->problem->id, $report->id;
    is $comment->user->id, $comment_user->id;
    is $comment->external_id, 'auto-internal';
    is $comment->name, 'Glos Council';

    $mech->clear_emails_ok;
    FixMyStreet::Script::Alerts::send_updates();
    my $email = $mech->get_email;
};

subtest "test resending does not leave another initial auto-update" => sub {
    $report->discard_changes;
    $report->resend;
    $report->update;
    FixMyStreet::Script::Reports::send(0, 0, 1);
    my $comments = FixMyStreet::DB->resultset('Comment');
    is $comments->count, 1;
    $comments->delete;
    $report->delete;
};

$template->update({ email_text => 'Thanks for your report.

This is the email <a href="https://google.com">alternative</a>.',
});

subtest "test report creation with initial auto-update and alternative email text" => sub {

    my $report = make_report();
    my $report_id = $report->id;
    $mech->clear_emails_ok;

    my $user3 = $mech->log_in_ok('test-3@example.com');
    $mech->get_ok("/report/$report_id");
    $mech->submit_form_ok({ button => 'alert', with_fields => { type => 'updates' } });
    $mech->log_out_ok;

    FixMyStreet::Script::Alerts::send_updates();

    my @emails = $mech->get_email;

    is scalar @emails, 2, 'Two alerts sent';

    my ($email_for_reporter) = grep { $_->header('To') =~ /test-2/ } @emails;
    my ($email_for_subscriber) = grep { $_->header('To') =~ /test-3/ } @emails;

    is $mech->get_text_body_from_email($email_for_subscriber) =~ /Thanks for your report. We will investigate within 5 working days./, 1, "Text template sent to subscriber";
    is $mech->get_text_body_from_email($email_for_reporter) =~ /This is the email alternative \[https:\/\/google.com\]/, 1, "Email template sent to reporter";
    is $mech->get_html_body_from_email($email_for_reporter) =~ /<p style="margin: 0 0 16px 0;">\r\nThis is the email <a href\="https:\/\/google\.com">alternative<\/a>.<\/p>/, 1, "Email template text in paragraphs";

    my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body, is_superuser => 1);
    $mech->log_in_ok($counciluser->email);
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains('This is the email ', "Extra template email text displayed");
    my $update_id = $report->comments->first->id;
    $mech->get_ok("/admin/update_edit/$update_id");
    $mech->content_contains("Template email response:", "Template email input present");
    $mech->content_contains("This is the email ", "Template email input populated");
    $report->comments->first->delete;
    $update_id = $mech->create_comment_for_problem($report, $comment_user, 'User', 'Non-template update', 0, 'confirmed', 'confirmed')->id;
    $mech->get_ok("/admin/report_edit/$report_id");
    $mech->content_contains("Non-template update", 'Standard update text visible');
    $mech->content_lacks("Template email response:", 'Template email munged text not added');
    $mech->get_ok("/admin/update_edit/$update_id");
    $mech->content_contains("Text:", 'Text box shown for standard update');
    $mech->content_lacks("Template email response:", 'Email text box not shown for standard update');
};

subtest "confirmation links log a user in within 30 seconds of first use" => sub {
    set_fixed_time('2023-08-03T17:00:00Z');

    my $report = make_report();
    my $report_id = $report->id;
    my $user4_email = 'asdf@asdf.com';

    $mech->clear_emails_ok;
    $mech->log_out_ok;

    $mech->get_ok("/report/$report_id");
    my $resp = $mech->submit_form_ok({
        with_fields => {
            update => "still not fixed",
            name => "Joe Bloggs",
            username_register => $user4_email,
        }
    }, "submit update");
    my $email = $mech->get_email;
    ok $email, "got an email";

    my $url = $mech->get_link_from_email($email);

    # first visit
    $mech->get_ok($url);
    $mech->logged_in_ok;
    $mech->log_out_ok;

    # immediately again...
    $mech->get_ok($url);
    $mech->logged_in_ok;
    $mech->log_out_ok;

    # after 30 seconds...
    set_fixed_time('2023-08-03T17:00:31Z');
    $mech->get_ok($url);
    $mech->not_logged_in_ok;
};

done_testing;

sub make_report {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/around?pc=GL50+2PR');
        $mech->follow_link_ok({ text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                name => 'Joe Bloggs',
                category => 'Potholes',
            }
        }, "submit good details");
    };

    my $report = $user->problems->first;
    ok $report, "Found the report";

    FixMyStreet::Script::Reports::send();

    return $report;
}
