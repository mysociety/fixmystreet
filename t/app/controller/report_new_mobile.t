use Test::More;
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
        $mech->log_in_ok('user@example.org');
        $mech->post_ok( '/report/new/mobile', {
            service => 'iPhone',
            title => 'Title',
            detail => 'Problem detail',
            lat => 47.381817,
            lon => 8.529156,
            email => 'user@example.org',
            pc => '',
            name => 'Name',
        });
        my $res = $mech->response;
        ok $res->header('Content-Type') =~ m{^application/json\b}, 'response should be json';

        my $user = FixMyStreet::DB->resultset('User')->search({ email => 'user@example.org' })->first;
        my $a = FixMyStreet::DB->resultset('Alert')->search({ user_id => $user->id })->first;
        isnt $a, undef, 'User is signed up for alert';
    };
};

END {
    $mech->delete_user('user@example.org');
    done_testing();
}
