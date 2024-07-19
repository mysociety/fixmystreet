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

done_testing();
