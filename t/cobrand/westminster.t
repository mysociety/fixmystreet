use CGI::Simple;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Westminster');
$cobrand->mock('lookup_site_code', sub {
    my ($self, $row) = @_;
    return "My USRN" if $row->latitude == 51.501009;
});

my $body = $mech->create_body_ok(2504, 'Westminster City Council', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j' });
my $superuser = $mech->create_user_ok(
    'superuser@example.com',
    name => 'Test Superuser',
    is_superuser => 1
);
my $staff_user = $mech->create_user_ok(
    'westminster@example.com',
    name => 'Test User',
    from_body => $body
);
my $normal_user = $mech->create_user_ok(
    'westminster-resident@example.com',
    name => 'Public User'
);
my ($report) = $mech->create_problems_for_body(1, $body->id, 'Title');
my $comment1 = $mech->create_comment_for_problem($report, $normal_user, 'User', 'this update was left on the Westminster cobrand', 0, 'confirmed', 'confirmed', { cobrand => 'westminster' });
my $comment2 = $mech->create_comment_for_problem($report, $normal_user, 'User', 'this update was left on the fixmystreet.com cobrand', 0, 'confirmed', 'confirmed', { cobrand => 'fixmystreet' });
my $comment3 = $mech->create_comment_for_problem($report, $normal_user, 'User', 'this update was imported via Open311', 0, 'confirmed', 'confirmed', { cobrand => '' });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'westminster',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        updates_allowed => {
            westminster => 'staff',
        },
        oidc_login => {
            westminster => {
                client_id => 'example_client_id',
                secret => 'example_secret_key',
                auth_uri => 'http://oidc.example.org/oauth2/v2.0/authorize',
                token_uri => 'http://oidc.example.org/oauth2/v2.0/token',
                display_name => 'MyWestminster'
            }
        }
    }
}, sub {
    subtest 'Cobrand allows social auth' => sub {
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('westminster')->new();
        ok $cobrand->social_auth_enabled;
    };

    subtest 'Login button displayed correctly' => sub {
        $mech->get_ok("/auth");
        $mech->content_contains("Sign in with MyWestminster");
    };

    subtest 'Reports do not have update form' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('Provide an update');
    };

    subtest 'Reports show updates from Westminster cobrand' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains($comment1->text);
    };

    subtest 'Reports show updates from Open311' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains($comment3->text);
    };

    subtest "Reports don't show updates from fixmystreet.com cobrand" => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks($comment2->text);
    };
};

subtest 'Reports have an update form for superusers' => sub {
    # Westminster cobrand disables email signin, so we have to
    # login and *then* set the cobrand.
    $mech->log_in_ok( $superuser->email );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'westminster',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            updates_allowed => {
                westminster => 'staff',
            },
        },
    }, sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('Provide an update');
    };

    $mech->log_out_ok();
};

subtest 'Reports have an update form for staff users' => sub {
    $mech->log_in_ok( $staff_user->email );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'westminster',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            updates_allowed => {
                westminster => 'staff',
            },
        },
    }, sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('Provide an update');
    };
    $mech->log_out_ok();
};

for (
    {
        ALLOWED_COBRANDS => 'westminster',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            oidc_login => {
                westminster => 0
            }
        }
    },
    {
        ALLOWED_COBRANDS => 'westminster',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            oidc_login => {
                hounslow => {
                    client_id => 'example_client_id',
                    secret => 'example_secret_key',
                    auth_uri => 'http://oidc.example.org/oauth2/v2.0/authorize',
                    token_uri => 'http://oidc.example.org/oauth2/v2.0/token',
                    display_name => 'MyHounslow'
                }
            }
        }
    },
    {
        ALLOWED_COBRANDS => 'westminster',
        MAPIT_URL => 'http://mapit.uk/',
    }
) {
    FixMyStreet::override_config $_, sub {
        subtest 'Cobrand disallows social auth' => sub {
            my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('westminster')->new();
            ok !$cobrand->social_auth_enabled;
        };

        subtest 'Login button not displayed' => sub {
            $mech->get_ok("/auth");
            $mech->content_lacks("Login with MyWestminster");
        };
    };
}

$mech->delete_problems_for_body($body->id);
$mech->create_contact_ok(body_id => $body->id, category => 'Abandoned bike', email => "BIKE");
($report) = $mech->create_problems_for_body(1, $body->id, 'Bike', {
    category => "Abandoned bike", cobrand => 'westminster',
    latitude => 51.501009, longitude => -0.141588, areas => '2504',
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'westminster' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => { anonymous_account => { westminster => 'anon' } },
}, sub {
    subtest 'USRN set correctly' => sub {
        my $test_data = FixMyStreet::Script::Reports::send();
        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'BIKE';
        is $c->param('attribute[USRN]'), 'My USRN';
    };
};

for my $cobrand (qw(westminster fixmystreet)) {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => $cobrand,
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        subtest "No reporter alert created in $cobrand" => sub {
            my $user = $mech->log_in_ok('test@example.org');
            $mech->get_ok('/');
            $mech->submit_form_ok( { with_fields => { pc => 'SW1A1AA' } }, "submit location" );
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
            $mech->submit_form_ok( { with_fields => {
                title => 'Title', detail => 'Detail', category => 'Abandoned bike', name => 'Test Example',
            } }, 'submitted okay' );
            is $user->alerts->count, 0;
        };
    };
}

my $westminster = FixMyStreet::Cobrand::Westminster->new;
subtest 'correct config returned for USRN/UPRN lookup' => sub {
    my $actual = $westminster->lookup_site_code_config('USRN');
    delete $actual->{accept_feature}; # is_deeply doesn't like code
    is_deeply $actual, {
        buffer => 1000,
        proxy_url => "https://tilma.mysociety.org/resource-proxy/proxy.php",
        url => "https://westminster.assets/40/query",
        property => 'USRN',
    };
    $actual = $westminster->lookup_site_code_config('UPRN');
    delete $actual->{accept_feature}; # is_deeply doesn't like code
    is_deeply $actual, {
        buffer => 1000,
        proxy_url => "https://tilma.mysociety.org/resource-proxy/proxy.php",
        url => "https://westminster.assets/25/query",
        property => 'UPRN',
        accept_types => {
            Point => 1
        },
    };
};

subtest 'nearest UPRN returns correct point' => sub {
    my $cfg = {
        accept_feature => sub { 1 },
        property => 'UPRN',
        accept_types => {
            Point => 1,
        },
    };
    my $features = [
        # A couple of incorrect geometry types to check they're ignored...
        { geometry => { type => 'Polygon' } },
        { geometry => { type => 'LineString',
            coordinates => [ [ 527735, 181004 ], [ 527755, 181004 ] ] },
          properties => { fid => '20100024' } },
        # And two points which are further away than the above linestring,
        # the second of which is the closest to our testing point.
        { geometry => { type => 'Point',
            coordinates => [ 527795, 181024 ] },
          properties => { UPRN => '10012387122' } },
        { geometry => { type => 'Point',
            coordinates => [ 527739, 181009 ] },
          properties => { UPRN => '10012387123' } },
    ];
    is $westminster->_nearest_feature($cfg, 527745, 180994, $features), '10012387123';
};


done_testing();
