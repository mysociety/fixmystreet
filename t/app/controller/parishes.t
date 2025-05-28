use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    COBRAND_FEATURES => {
        parishes => {
            fixmystreet => 1,
        },
    },
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Parishes index page works and shows form' => sub {
        $mech->get_ok('/parishes');
        $mech->content_contains('<form', 'Page contains a form');

        $mech->content_contains('Your details', 'Page contains your details section');

        # submit form ok
        $mech->submit_form_ok({
            with_fields => {
                name => 'Test User',
                email => 'test@example.com',
            },
        });
    };
};

done_testing();
