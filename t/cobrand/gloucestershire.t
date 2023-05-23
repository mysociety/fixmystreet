use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;
my $cobrand = FixMyStreet::Cobrand::Gloucestershire->new;
my $body = $mech->create_body_ok(
    2226,
    'Gloucestershire County Council',
    {   send_method  => 'Open311',
        api_key      => 'key',
        endpoint     => 'endpoint',
        jurisdiction => 'jurisdiction',
    },
    { cobrand => 'gloucestershire', },
);

$mech->create_contact_ok(
    body_id  => $body->id,
    category => 'Graffiti',
    email    => 'GLOS_GRAFFITI',
);

my $standard_user_1
    = $mech->create_user_ok( 'user1@email.com', name => 'User 1' );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'gloucestershire' ],
    MAPIT_URL        => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        anonymous_account => { gloucestershire => 'anonymous.fixmystreet' },
    },
}, sub {
    ok $mech->host('gloucestershire'), 'change host to gloucestershire';
    $mech->get_ok('/');
    $mech->content_like(qr/Enter a Gloucestershire postcode/);

    subtest 'variations of example search location are disambiguated' => sub {
        for my $string (
            'Gloucester Road, Tewkesbury',
            '  gloucester  rd,tewkesbury  ',
        ) {
            is $cobrand->disambiguate_location($string)->{town},
                'Gloucestershire, GL20 5XA', $string;
        }
    };

    subtest 'test report creation anonymously by button' => sub {
        $mech->log_in_ok( $standard_user_1->email );
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR' } },
            'submit location' );
        $mech->follow_link_ok(
            { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link"
        );

        $mech->submit_form_ok(
            {   button      => 'report_anonymously',
                with_fields => {
                    title    => 'Anon report',
                    detail   => 'ABC',
                    category => 'Graffiti',
                }
            },
            'submit report anonymously',
        );
        is_deeply $mech->page_errors, [], 'check there were no errors';

        my $report = FixMyStreet::DB->resultset('Problem')
            ->find( { title => 'Anon report' } );
        ok $report, 'report found in DB';
        is $report->state, 'confirmed', 'report confirmed';
        is $report->name, 'Anonymous user';
        is $report->user->email,
            'anonymous.fixmystreet@gloucestershire.gov.uk';
        is $report->anonymous,                            1;
        is $report->get_extra_metadata('contributed_as'), 'anonymous_user';

        my $alert = FixMyStreet::App->model('DB::Alert')->find(
            {   user       => $report->user,
                alert_type => 'new_updates',
                parameter  => $report->id,
            }
        );
        is $alert, undef, "no alert created";

        $mech->log_out_ok;
    };
};

done_testing();
