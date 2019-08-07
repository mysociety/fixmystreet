use CGI::Simple;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Westminster');
$cobrand->mock('lookup_site_code', sub {
    my ($self, $row, $buffer) = @_;
    return "My USRN" if $row->latitude == 51.501009;
});

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

    subtest 'Reports do not have update form' => sub {
        my ($report) = $mech->create_problems_for_body(1, 2504, 'Title');
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('Provide an update');
    }
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

FixMyStreet::DB->resultset('Problem')->delete_all;
my $body = $mech->create_body_ok(2504, 'Westminster City Council', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j' });
$mech->create_contact_ok(body_id => $body->id, category => 'Abandoned bike', email => "BIKE");
my ($report) = $mech->create_problems_for_body(1, $body->id, 'Bike', {
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

done_testing();
