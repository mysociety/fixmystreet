use FixMyStreet::TestMech;
use Test::MockModule;
use Storable;
use MIME::Base64;


ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my @urls = (
    "/",
    "/contact",
    "/about/faq",
    "/around?longitude=-1.351488&latitude=51.847235"
);


FixMyStreet::override_config {
    LOGIN_REQUIRED => 0,
    MAPIT_URL => 'http://mapit.uk/'
}, sub {
    subtest 'LOGIN_REQUIRED = 0 behaves correctly' => sub {
        foreach my $url (@urls) {
            $mech->get_ok($url);
            is $mech->res->code, 200, "got 200 for page";
            is $mech->res->previous, undef, 'No redirect';
        }
    };
};


FixMyStreet::override_config {
    LOGIN_REQUIRED => 1,
    MAPIT_URL => 'http://mapit.uk/'
}, sub {
    subtest 'LOGIN_REQUIRED = 1 redirects to /auth if not logged in' => sub {
        foreach my $url (@urls) {
            $mech->get_ok($url);
            is $mech->res->code, 200, "got 200 for final destination";
            is $mech->res->previous->code, 302, "got 302 for redirect";
            is $mech->uri->path, '/auth';
        }
    };

    subtest 'LOGIN_REQUIRED = 1 does not redirect if logged in' => sub {
        $mech->log_in_ok('user@example.org');
        foreach my $url (@urls) {
            $mech->get_ok($url);
            is $mech->res->code, 200, "got 200 for final destination";
            is $mech->res->previous, undef, 'No redirect';
        }
        $mech->log_out_ok;
    };

    subtest 'LOGIN_REQUIRED = 1 allows whitelisted URLs' => sub {
        my @whitelist = (
            '/auth',
            '/js/translation_strings.en-gb.js'
        );

        foreach my $url (@whitelist) {
            $mech->get_ok($url);
            is $mech->res->code, 200, "got 200 for final destination";
            is $mech->res->previous, undef, 'No redirect';
        }
    };
};

subtest "check_login_disallowed cobrand hook" => sub {
    my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Default');
    $cobrand->mock('check_login_disallowed', sub {
            my $self = shift;
            return 0 if $self->{c}->req->path eq 'auth';
            return 1;
        }
    );

    $mech->get_ok('/');
    is $mech->uri->path_query, '/auth?r=', 'redirects to auth page';
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        android_assetlinks => {
            fixmystreet => {
                package => "org.mysociety.FixMyStreet"
            }
        }
    }
}, sub {

    subtest "Session not created if PWA not used" => sub {
        FixMyStreet::DB->resultset("Session")->delete_all;

        $mech->get_ok('/'); # we're a regular front page visitor, not using app
        my $count = FixMyStreet::DB->resultset("Session")->count;
        is $count, 0, "session not created";
    };

    subtest "Android start URL stores platform in session" => sub {
        FixMyStreet::DB->resultset("Session")->delete_all;

        $mech->get_ok('/?pwa=android');
        my $session = FixMyStreet::DB->resultset("Session")->first;
        my $data = Storable::thaw(MIME::Base64::decode($session->session_data));

        is $data->{app_platform}, "Android";
    };

    subtest "iOS start URL stores platform in session" => sub {
        FixMyStreet::DB->resultset("Session")->delete_all;

        $mech->get_ok('/?pwa=ios');
        my $session = FixMyStreet::DB->resultset("Session")->first;
        my $data = Storable::thaw(MIME::Base64::decode($session->session_data));

        is $data->{app_platform}, "iOS";
    };

    subtest "Invalid start URL pwa parameter doesn't create session" => sub {
        FixMyStreet::DB->resultset("Session")->delete_all;

        $mech->get_ok('/?pwa=unknown');
        my $count = FixMyStreet::DB->resultset("Session")->count;
        is $count, 0, "session not created";
    };

    subtest "iOS User-Agent header stores platform in session" => sub {
        FixMyStreet::DB->resultset("Session")->delete_all;

        my $agent = $mech->agent;
        $mech->agent("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1 iospwa");

        $mech->get_ok('/');
        my $session = FixMyStreet::DB->resultset("Session")->first;
        my $data = Storable::thaw(MIME::Base64::decode($session->session_data));

        is $data->{app_platform}, "iOS";

        $mech->agent($agent);
    };

    subtest "Android android-app:// referer stores platform in session" => sub {
        FixMyStreet::DB->resultset("Session")->delete_all;

        $mech->add_header(Referer => "android-app://org.mysociety.FixMyStreet/");
        $mech->get_ok('/');
        my $session = FixMyStreet::DB->resultset("Session")->first;
        my $data = Storable::thaw(MIME::Base64::decode($session->session_data));

        is $data->{app_platform}, "Android";

        $mech->delete_header('Referer');
    };

    subtest "Android android-app:// referer from another app doesn't create session" => sub {
        FixMyStreet::DB->resultset("Session")->delete_all;

        $mech->add_header(Referer => "android-app://com.google.android.gm/");
        $mech->get_ok('/');
        my $count = FixMyStreet::DB->resultset("Session")->count;
        is $count, 0, "session not created";

        $mech->delete_header('Referer');
    };
};
done_testing();
