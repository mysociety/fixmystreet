use FixMyStreet::TestMech;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'westminster',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
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
        $mech->content_contains("Login with MyWestminster");
    };
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

done_testing();
