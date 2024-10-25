use FixMyStreet::TestMech;
use LWP::Protocol::PSGI;
use t::Mock::MapItZurich;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

LWP::Protocol::PSGI->register(t::Mock::MapItZurich->to_psgi_app, host => 'mapit.zurich');

subtest "Check signed up for alert when logged in" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.zurich',
        MAPIT_TYPES => [ 'O08' ],
    }, sub {
        my $user = $mech->log_in_ok('user@example.org');
        $mech->post_ok( '/report/new/mobile', {
            service => 'iPhone',
            title => 'Title',
            detail => 'Problem detail',
            lat => 47.381817,
            lon => 8.529156,
            email => $user->email,
            pc => '',
            name => 'Name',
        });
        my $res = $mech->response;
        ok $res->header('Content-Type') =~ m{^application/json\b}, 'response should be json';

        my $a = FixMyStreet::DB->resultset('Alert')->search({ user_id => $user->id })->first;
        isnt $a, undef, 'User is signed up for alert';
    };
};

my $body = $mech->create_body_ok(2651, 'Edinburgh', {});
my $user = $mech->create_user_ok('publicuser@example.com', name => 'Fred Again');

$mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street lighting',
    email => 'highways@example.com',
);
$mech->create_contact_ok(
    body_id => $body->id,
    category => 'Trees',
    email => 'trees@example.com',
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

for my $test (
    { param => 'ios', service => 'iOS' },
    { param => 'android', service => 'Android' },
    { param => 'unknown', service => 'mobile' },
    { param => undef, service => 'mobile' },
) {

    subtest "App platform stored in service field" => sub {
        FixMyStreet::DB->resultset("Problem")->delete_all;
        FixMyStreet::DB->resultset("Session")->delete_all;
        $mech->log_in_ok($user->email);

        my $url = $test->{param} ? "/?pwa=" . $test->{param} : "/";
        $mech->get_ok($url);

        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                button => 'submit_register_mobile',
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
