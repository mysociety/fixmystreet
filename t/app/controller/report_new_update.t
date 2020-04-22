use FixMyStreet::TestMech;

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

subtest "test report creation with initial auto-update" => sub {
    my $report = make_report();
    my $comment = FixMyStreet::DB->resultset('Comment')->single;
    is $comment->text, 'Thanks for your report. We will investigate within 5 working days.';
    is $comment->problem->id, $report->id;
    is $comment->user->id, $comment_user->id;
    is $comment->external_id, 'auto-internal';
    is $comment->name, 'Glos Council';
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

    return $report;
}
