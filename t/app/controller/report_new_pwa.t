use FixMyStreet::TestMech;
use LWP::Protocol::PSGI;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(2651, 'Edinburgh', {}, {});
my $user = $mech->create_user_ok('publicuser@example.com', name => 'Fred Again');

$mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street lighting',
    email => 'highways@example.com',
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

for my $test (
    { button => 'submit_register_mobile', service => 'PWA (mobile)' },
    { button => 'submit_register', service => 'PWA (desktop)' },
    { button => undef, service => 'PWA' },
) {

    subtest "App platform stored in service field" => sub {
        FixMyStreet::DB->resultset("Problem")->delete_all;
        FixMyStreet::DB->resultset("Session")->delete_all;
        $mech->log_in_ok($user->email);

        $mech->get_ok('/?pwa');
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                button => $test->{button},
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

        my $report = FixMyStreet::DB->resultset("Problem")->first;
        ok $report, "Found the report";

        is $report->state, 'confirmed', "report confirmed";
        is $report->service, $test->{service}, "service is correct value";
        $mech->get_ok( '/report/' . $report->id );

        $mech->log_out_ok;
    };

}
};

END {
    done_testing();
}
