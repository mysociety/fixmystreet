use Test::MockTime qw(set_fixed_time);
use FixMyStreet::TestMech;
use FixMyStreet::Cobrand::Merton;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

$mech->create_body_ok(2500, 'Merton Council', { cobrand => 'merton' });

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
                    receive_password => [ 'password2', 'password' ]
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
        my $cobrand = FixMyStreet::Cobrand::Merton->new;
        my $now = DateTime->new( year => 2024, month => 7, day => 23, time_zone => FixMyStreet->local_time_zone );
        subtest 'before a period' => sub {
            $now->set_hour(16);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get_ok('/waste');
            $mech->content_lacks('Due to planned maintenance');
            $mech->content_lacks('Please accept our apologies');
            is $cobrand->waste_check_downtime_file->{state}, 'up';
        };
        subtest 'in warning period' => sub {
            $now->set_hour(18);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get_ok('/waste');
            $mech->content_contains('Due to planned maintenance');
            $mech->content_contains('from  8pm until 11pm');
            $mech->content_lacks('Please accept our apologies');
            is $cobrand->waste_check_downtime_file->{state}, 'upcoming';
        };
        subtest 'in closure period' => sub {
            $now->set_hour(20);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get('/waste');
            is $mech->res->code, 503;
            $mech->content_contains('Due to planned maintenance');
            $mech->content_contains('from  8pm until 11pm');
            $mech->content_contains('Please accept our apologies');
            $mech->content_contains('Planned maintenance');
            is $cobrand->waste_check_downtime_file->{state}, 'down';
        };
        subtest 'end of closure period, in buffer' => sub {
            $now->set_hour(23);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get('/waste');
            is $mech->res->code, 503;
            $mech->content_contains('Due to planned maintenance');
            $mech->content_contains('from  8pm until 11pm');
            $mech->content_contains('Please accept our apologies');
            is $cobrand->waste_check_downtime_file->{state}, 'down';
        };
        subtest 'after closure period buffer' => sub {
            $now->set_minute(15);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get_ok('/waste');
            $mech->content_lacks('Due to planned maintenance');
            $mech->content_lacks('Please accept our apologies');
            is $cobrand->waste_check_downtime_file->{state}, 'up';
        };

        $now = DateTime->new( year => 2025, month => 4, day => 1, time_zone => FixMyStreet->local_time_zone );
        subtest 'Unplanned downtime' => sub {
            $now->set_hour(10);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get('/waste');
            is $mech->res->code, 503;
            $mech->content_contains('Please refrain from calling');
            $mech->content_contains('Temporarily unavailable');
            is $cobrand->waste_check_downtime_file->{state}, 'down';
            is $cobrand->waste_check_downtime_file->{unplanned}, 1;
        };

        $now = DateTime->new( year => 2025, month => 4, day => 8, time_zone => FixMyStreet->local_time_zone );
        subtest 'Unplanned downtime, special message' => sub {
            $now->set_hour(10);
            set_fixed_time($now->clone->set_time_zone('UTC'));
            $mech->get('/waste');
            is $mech->res->code, 503;
            $mech->content_contains('This is a special message');
            is $cobrand->waste_check_downtime_file->{state}, 'down';
        };
    };
};

done_testing();
