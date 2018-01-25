use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        bodies_str         => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Report to Edit',
        detail             => 'Detail for Report to Edit',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        external_id        => '13',
        state              => 'confirmed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => '',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
        whensent           => $dt->ymd . ' ' . $dt->hms,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

my $alert = FixMyStreet::App->model('DB::Alert')->find_or_create(
    {
        alert_type => 'area_problems',
        parameter => 2482,
        confirmed => 1,
        user => $user,
    },
);

$mech->log_in_ok( $superuser->email );

subtest 'check summary counts' => sub {
    my $problems = FixMyStreet::App->model('DB::Problem')->search( { state => { -in => [qw/confirmed fixed closed investigating planned/, 'in progress', 'fixed - user', 'fixed - council'] } } );

    ok $mech->host('www.fixmystreet.com');

    my $problem_count = $problems->count;
    $problems->update( { cobrand => '' } );

    FixMyStreet::App->model('DB::Problem')->search( { bodies_str => 2489 } )->update( { bodies_str => 1 } );

    my $q = FixMyStreet::App->model('DB::Questionnaire')->find_or_new( { problem => $report, });
    $q->whensent( \'current_timestamp' );
    $q->in_storage ? $q->update : $q->insert;

    my $alerts =  FixMyStreet::App->model('DB::Alert')->search( { confirmed => { '>' => 0 } } );
    my $a_count = $alerts->count;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
    }, sub {
        $mech->get_ok('/admin');
    };

    $mech->title_like(qr/Summary/);

    $mech->content_contains( "$problem_count</strong> live problems" );
    $mech->content_contains( "$a_count confirmed alerts" );

    my $questionnaires = FixMyStreet::App->model('DB::Questionnaire')->search( { whensent => { -not => undef } } );
    my $q_count = $questionnaires->count();

    $mech->content_contains( "$q_count questionnaires sent" );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        ok $mech->host('oxfordshire.fixmystreet.com');

        $mech->get_ok('/admin');
        $mech->title_like(qr/Summary/);

        my ($num_live) = $mech->content =~ /(\d+)<\/strong> live problems/;
        my ($num_alerts) = $mech->content =~ /(\d+) confirmed alerts/;
        my ($num_qs) = $mech->content =~ /(\d+) questionnaires sent/;

        $report->bodies_str($oxfordshire->id);
        $report->cobrand('oxfordshire');
        $report->update;

        $alert->cobrand('oxfordshire');
        $alert->update;

        $mech->get_ok('/admin');

        $mech->content_contains( ($num_live+1) . "</strong> live problems" );
        $mech->content_contains( ($num_alerts+1) . " confirmed alerts" );
        $mech->content_contains( ($num_qs+1) . " questionnaires sent" );

        $report->bodies_str(2504);
        $report->cobrand('');
        $report->update;

        $alert->cobrand('');
        $alert->update;
    };

    FixMyStreet::App->model('DB::Problem')->search( { bodies_str => 1 } )->update( { bodies_str => 2489 } );
    ok $mech->host('www.fixmystreet.com');
};

subtest "Check admin_base_url" => sub {
    my $rs = FixMyStreet::App->model('DB::Problem');
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($report->cobrand)->new();

    is ($report->admin_url($cobrand),
        (sprintf 'http://www.example.org/admin/report_edit/%d', $report_id),
        'get_admin_url OK');
};

# Finished with the superuser tests
$mech->log_out_ok;

subtest "Users without from_body can't access admin" => sub {
    $mech->log_in_ok( $user->email );

    ok $mech->get('/admin');
    is $mech->res->code, 403, "got 403";

    $mech->log_out_ok;
};

subtest "Users with from_body can access their own council's admin" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $mech->log_in_ok( $oxfordshireuser->email );

        $mech->get_ok('/admin');
        $mech->content_contains( 'FixMyStreet admin:' );

        $mech->log_out_ok;
    };
};

subtest "Users with from_body can't access another council's admin" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bristol' ],
    }, sub {
        $mech->log_in_ok( $oxfordshireuser->email );

        ok $mech->get('/admin');
        is $mech->res->code, 403, "got 403";

        $mech->log_out_ok;
    };
};

subtest "Users with from_body can't access fixmystreet.com admin" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
    }, sub {
        $mech->log_in_ok( $oxfordshireuser->email );

        ok $mech->get('/admin');
        is $mech->res->code, 403, "got 403";

        $mech->log_out_ok;
    };
};

done_testing();
