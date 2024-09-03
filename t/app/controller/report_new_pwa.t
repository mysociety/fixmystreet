use FixMyStreet::TestMech;
use LWP::Protocol::PSGI;
use t::Mock::MapItZurich;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(2651, 'Edinburgh', {}, {});
my $user = $mech->create_user_ok('publicuser@example.com', name => 'Not Fred Again');

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
        { service => 'desktop' },
        { service => 'mobile' },
    ) {
        $mech->log_in_ok($user->email);
        subtest "Appends '(probably PWA)' to service if probably PWA" => sub {
            FixMyStreet::DB->resultset("Problem")->delete_all;
            $mech->get_ok('/around');
            $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );

            # Enable the probably PWA form - normally the javascript would do this for us.
            my $form = $mech->current_form();
            my $probably_pwa_field = $form->find_input('probably_pwa');
            $probably_pwa_field->disabled(0);

            $mech->submit_form_ok(
                {
                    button => 'submit_register',
                    with_fields => {
                        service => $test->{service},
                        title => 'Test Report',
                        detail => 'Test report details.',
                        category => 'Street lighting',
                        probably_pwa => 1,
                    }
                },
                "submit good details"
            );
            $mech->content_contains('Thank you');
            is_deeply $mech->page_errors, [], "check there were no errors";

            my $report = FixMyStreet::DB->resultset("Problem")->first;
            ok $report, "Found the report";

            is $report->state, 'confirmed', "report confirmed";
            is $report->service, $test->{service} . " (probably PWA)", "service is correct value";
            $mech->log_out_ok;
        };
    }
};

END {
    done_testing();
}
