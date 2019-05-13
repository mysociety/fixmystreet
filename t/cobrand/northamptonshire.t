use Test::MockModule;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use open ':std', ':encoding(UTF-8)'; 

my $ncc = $mech->create_body_ok(2234, 'Northamptonshire County Council');
my $nbc = $mech->create_body_ok(2397, 'Northampton Borough Council');

my $ncc_contact = $mech->create_contact_ok(
    body_id => $ncc->id,
    category => 'Trees',
    email => 'trees-2234@example.com',
);

my $nbc_contact = $mech->create_contact_ok(
    body_id => $nbc->id,
    category => 'Flytipping',
    email => 'flytipping-2397@example.com',
);

subtest 'Check district categories hidden on cobrand' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { northamptonshire => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok( '/around' );
        $mech->submit_form_ok( { with_fields => { pc => 'NN1 1NS' } },
            "submit location" );
        is_deeply $mech->page_errors, [], "no errors for pc";

        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->content_contains('Trees');
        $mech->content_lacks('Flytipping');
    };
};

done_testing();
