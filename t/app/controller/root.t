use FixMyStreet::TestMech;
use Test::MockModule;

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

    subtest 'LOGIN_REQUIRED = 1 404s blacklisted URLs' => sub {
        my @blacklist = (
            '/offline/appcache',
        );

        foreach my $url (@blacklist) {
            $mech->get($url);
            ok !$mech->res->is_success(), "want a bad response";
            is $mech->res->code, 404, "got 404";
        }
    };
};

subtest "check_login_disallowed cobrand hook" => sub {
    warn '#' x 50 . "\n";
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

done_testing();
