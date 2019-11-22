use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council' );
my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Cows', email => 'cows@example.net' );

my ($report) = $mech->create_problems_for_body(1, $oxon->id, 'Test', {
    category => 'Cows', cobrand => 'fixmystreet',
});
my $report_id = $report->id;


foreach my $council (qw/oxfordshire bromley/) {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ $council ],
    }, sub {
        ok $mech->host("$council.fixmystreet.com"), "change host to $council";
        $mech->get_ok('/');
        $mech->content_like( qr/\u$council/ );
    };
}


foreach my $test (
    { cobrand => 'fixmystreet', social => 1 },
    { cobrand => 'bromley', social => 0 },
) {

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ $test->{cobrand} ],
        FACEBOOK_APP_ID => 'facebook-app-id',
        TWITTER_KEY => 'twitter-key',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/auth');
        $mech->contains_or_lacks($test->{social}, "Log in with Facebook");
        $mech->contains_or_lacks($test->{social}, "Log in with Twitter");

        $mech->get_ok("/report/new?lat=51.754926&lon=-1.256179");
        $mech->contains_or_lacks($test->{social}, "Log in with Facebook");
        $mech->contains_or_lacks($test->{social}, "Log in with Twitter");

        $mech->get_ok("/report/$report_id");
        $mech->contains_or_lacks($test->{social}, "Log in with Facebook");
        $mech->contains_or_lacks($test->{social}, "Log in with Twitter");
    };
};


subtest "Test update shown/not shown appropriately" => sub {
    my $user = $mech->create_user_ok('test@example.com');
    foreach my $cobrand ('oxfordshire', 'fixmystreet') {
        foreach my $test (
            # Three bools are logged out, reporter, staff user
            { type => 'none', update => [0,0,0] },
            { type => 'staff', update => [0,0,1] },
            { type => 'reporter', update => [0,1,1] },
            { type => 'reporter-open', state => 'closed', update => [0,0,0] },
            { type => 'reporter-open', state => 'in progress', update => [0,1,1] },
            { type => 'open', state => 'closed', update => [0,0,0] },
            { type => 'open', state => 'in progress', update => [1,1,1] },
        ) {
            FixMyStreet::override_config {
                ALLOWED_COBRANDS => $cobrand,
                MAPIT_URL => 'http://mapit.uk/',
                COBRAND_FEATURES => {
                    updates_allowed => {
                        oxfordshire => $test->{type},
                        fixmystreet => {
                            Oxfordshire => $test->{type},
                        }
                    }
                },
            }, sub {
                subtest "$cobrand, $test->{type}" => sub {
                    $report->update({ state => $test->{state} || 'confirmed' });
                    $mech->log_out_ok;
                    $user->update({ from_body => undef });
                    $mech->get_ok("/report/$report_id");
                    $mech->contains_or_lacks($test->{update}[0], 'Provide an update');
                    $mech->log_in_ok('test@example.com');
                    $mech->get_ok("/report/$report_id");
                    $mech->contains_or_lacks($test->{update}[1], 'Provide an update');
                    $user->update({ from_body => $oxon->id });
                    $mech->get_ok("/report/$report_id");
                    $mech->contains_or_lacks($test->{update}[2], 'Provide an update');
                };
            };
        }
    }
};

subtest "CSP header from feature" => sub {
    foreach my $cobrand (
        { moniker => 'oxfordshire', test => 'oxon.analytics.example.org' },
        { moniker =>'fixmystreet', test => '' },
        { moniker => 'nonsecure', test => undef },
    ) {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => $cobrand->{moniker},
            COBRAND_FEATURES => {
                content_security_policy => {
                    oxfordshire => 'oxon.analytics.example.org',
                    fixmystreet => 1,
                }
            },
        }, sub {
            $mech->get_ok("/");
            if (defined $cobrand->{test}) {
                like $mech->res->header('Content-Security-Policy'), qr/script-src 'self' 'unsafe-inline' 'nonce-[^']*' $cobrand->{test}/;
            } else {
                is $mech->res->header('Content-Security-Policy'), undef;
            }
        };
    }
};

done_testing();
