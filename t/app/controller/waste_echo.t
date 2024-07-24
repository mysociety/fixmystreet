use Test::MockTime qw(set_fixed_time);
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

$mech->create_body_ok(2500, 'Merton Council', {}, { cobrand => 'merton' });

subtest 'echo-push-only flag' => sub {
    my $in = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
  <Header> <Action>action</Action> <Security><UsernameToken><Username>un</Username><Password>password</Password></UsernameToken></Security> </Header>
  <Body> <NotifyEventUpdated> <event> <!-- skipped --> </event> </NotifyEventUpdated> </Body>
</Envelope>
EOF
    foreach ('0', 'echo-push-only') {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'merton',
            COBRAND_FEATURES => {
                echo => { merton => {
                    url => 'https://www.example.org/',
                    receive_action => 'action',
                    receive_username => 'un',
                    receive_password => 'password',
                } },
                waste => { merton => $_ }
            },
        }, sub {
            $mech->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
            if ($_) {
                $mech->content_contains('<NotifyEventUpdatedResponse');
            } else {
                is $mech->res->code, 404;
            }
        };
    }
};

subtest 'Echo downtime' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'merton',
        COBRAND_FEATURES => {
            waste => { merton => 1 },
            echo => { merton => { downtime_csv => 't/fixtures/echo-downtime.csv' } },
        },
    }, sub {
        my $now = DateTime->new( year => 2024, month => 7, day => 23, time_zone => FixMyStreet->local_time_zone );
        subtest 'before a period' => sub {
            $now->set_hour(16);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get_ok('/waste');
            $mech->content_lacks('Due to planned maintenance');
            $mech->content_lacks('Please accept our apologies');
        };
        subtest 'in warning period' => sub {
            $now->set_hour(18);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get_ok('/waste');
            $mech->content_contains('Due to planned maintenance');
            $mech->content_contains('from  8pm until 11pm');
            $mech->content_lacks('Please accept our apologies');
        };
        subtest 'in closure period' => sub {
            $now->set_hour(20);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get('/waste');
            is $mech->res->code, 503;
            $mech->content_contains('Due to planned maintenance');
            $mech->content_contains('from  8pm until 11pm');
            $mech->content_contains('Please accept our apologies');
        };
        subtest 'end of closure period, in buffer' => sub {
            $now->set_hour(23);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get('/waste');
            is $mech->res->code, 503;
            $mech->content_contains('Due to planned maintenance');
            $mech->content_contains('from  8pm until 11pm');
            $mech->content_contains('Please accept our apologies');
        };
        subtest 'after closure period buffer' => sub {
            $now->set_minute(15);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get_ok('/waste');
            $mech->content_lacks('Due to planned maintenance');
            $mech->content_lacks('Please accept our apologies');
        };
    };
};

done_testing();
