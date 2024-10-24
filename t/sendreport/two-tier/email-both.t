use FixMyStreet::Cobrand;
use FixMyStreet::Script::Reports;
use FixMyStreet::TestMech;
use Test::Deep;
use Test::MockModule;
use Test::MockObject;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('user@example.com');

my $body_oxf = $mech->create_body_ok( 2237, 'Oxfordshire County Council',
    { cobrand => 'oxfordshire' } );
my $body_cherwell
    = $mech->create_body_ok( 2419, 'Cherwell District Council' );

$mech->create_contact_ok(
    body_id     => $body_oxf->id,
    category    => 'Other',
    email       => 'other@oxfordshire.com',
    send_method => 'Email::Highways',
);
$mech->create_contact_ok(
    body_id  => $body_cherwell->id,
    category => 'Other',
    email    => 'other@cherwell.com',
);

my ($report) = $mech->create_problems_for_body(
    1,
    ( join ',', $body_oxf->id, $body_cherwell->id ),
    'Test',
    {   cobrand  => 'fixmystreet',
        category => 'Other',
        user     => $user,
    }
);

my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('fixmystreet')->new;
$report->result_source->schema->cobrand($cobrand);

my $mock_email = Test::MockModule->new('FixMyStreet::SendReport::Email');

subtest '1st attempt - both fail' => sub {
    is $report->duration_string, undef,
        'duration string is undef before any sending attempt';

    my $hits = 0;
    $mock_email->mock(
        'send',
        sub {
            my ( $self, undef, $h ) = @_;

            cmp_bag [ map { $_->id } @{ $self->bodies } ],
                [ $body_cherwell->id, $body_oxf->id ],
                'Sender should have both bodies';

            like $h->{bodies_name}, qr/Cherwell.*Oxfordshire/,
                'bodies_name for email should contain both bodies';
            $hits++;

            $self->error('Email fail');
            return -1;
        }
    );
    test_send();
    $report->discard_changes;

    is $hits, 1, 'Email sender hit once';

    is $report->whensent,         undef, 'whensent not recorded';
    is $report->send_method_used, undef, 'send_method_used not recorded';

    ok $report->send_fail_timestamp, 'send_fail_timestamp recorded';
    is $report->send_fail_count,  1,            'send_fail_count recorded';
    is $report->send_fail_reason, 'Email fail', 'send_fail_reason recorded';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id, $body_cherwell->id ],
        'Failed body ID saved for each body';

    is $report->body(1), '', 'no body for duration_string';
};

subtest '2nd attempt - both fail again' => sub {
    my $hits = 0;
    $mock_email->mock(
        'send',
        sub {
            my ( $self, undef, $h ) = @_;

            cmp_bag [ map { $_->id } @{ $self->bodies } ],
                [ $body_cherwell->id, $body_oxf->id ],
                'Sender should have both bodies';

            like $h->{bodies_name}, qr/Cherwell.*Oxfordshire/,
                'bodies_name for email should contain both bodies';
            $hits++;

            $self->error('Email fail');
            return -1;
        }
    );
    test_send();
    $report->discard_changes;

    is $hits, 1, 'Email sender hit once';

    is $report->whensent,         undef, 'whensent not recorded';
    is $report->send_method_used, undef, 'send_method_used not recorded';

    is $report->send_fail_count, 2, 'send_fail_count updated';
    is $report->send_fail_reason, 'Email fail',
        'send_fail_reason stays the same';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id, $body_cherwell->id ],
        'send_fail_body_ids remain the same';

    is $report->body(1), '', 'no body for duration_string';
};

subtest '3rd attempt - both succeed' => sub {
    my $hits = 0;
    $mock_email->mock(
        'send',
        sub {
            my ( $self, undef, $h ) = @_;

            cmp_bag [ map { $_->id } @{ $self->bodies } ],
                [ $body_cherwell->id, $body_oxf->id ],
                'Sender should have both bodies';

            like $h->{bodies_name}, qr/Cherwell.*Oxfordshire/,
                'bodies_name for email should contain both bodies';
            $hits++;

            $self->success(1);
            return 0;
        }
    );
    test_send();
    $report->discard_changes;

    is $hits, 1, 'Email sender hit once';

    ok $report->whensent, 'whensent recorded';
    is $report->send_method_used, 'Email', 'send_method_used recorded';

    is $report->send_fail_count, 2, 'send_fail_count unchanged';
    is $report->send_fail_reason, 'Email fail',
        'send_fail_reason stays the same';
    cmp_bag $report->send_fail_body_ids, [], 'send_fail_body_ids removed';

    is $report->body(1),
        'Cherwell District Council and Oxfordshire County Council',
        'Both bodies for duration_string';
};

subtest '4th attempt - email set to fail again' => sub {
    # Expected behaviour:
    # Since email succeeded previously, its failure here will be
    # ignored

    my $hits = 0;
    $mock_email->mock(
        'send',
        sub {
            my $self = shift;

            $hits++;

            $self->error('Email fail');
            return -1;
        }
    );
    test_send();
    $report->discard_changes;

    is $hits, 0, 'Email sender not hit';

    is $report->send_method_used, 'Email', 'send_method_used unchanged';

    is $report->send_fail_count,  2,            'send_fail_count unchanged';
    is $report->send_fail_reason, 'Email fail', 'send_fail_reason unchanged';
    cmp_bag $report->send_fail_body_ids, [], 'send_fail_body_ids unchanged';

    is $report->body(1),
        'Cherwell District Council and Oxfordshire County Council',
        'Bodies for duration_string unchanged';
};

subtest 'Test resend' => sub {
    # Call 'resend'; we expect certain fields to be unset
    $report->resend;
    $report->update;

    is $report->whensent,         undef, 'whensent unset';
    is $report->send_method_used, undef, 'send_method_used unset';

    is $report->send_fail_count,  2,            'send_fail_count unmodified';
    is $report->send_fail_reason, 'Email fail', 'send_fail_reason unmodified';
    cmp_bag $report->send_fail_body_ids, [], 'send_fail_body_ids unset';

    is $report->body(1),
        'Cherwell District Council and Oxfordshire County Council',
        'Both bodies for duration_string';

    my $hits = 0;
    $mock_email->mock(
        'send',
        sub {
            my $self = shift;

            $hits++;

            $self->success(1);
            return 0;
        }
    );
    test_send();
    $report->discard_changes;

    is $hits, 1, 'Email sender hit once';

    is $report->send_method_used, 'Email', 'send_method_used unchanged';

    is $report->send_fail_count,  2,            'send_fail_count unchanged';
    is $report->send_fail_reason, 'Email fail', 'send_fail_reason unchanged';
    cmp_bag $report->send_fail_body_ids, [], 'send_fail_body_ids unchanged';

    is $report->body(1),
        'Cherwell District Council and Oxfordshire County Council',
        'Both bodies for duration_string';
};

subtest 'Test staging send' => sub {
    # Will send with send_reports flag set to 0

    my $hits = 0;
    $mock_email->mock(
        send => sub {
            my ( $self, undef, $h ) = @_;

            cmp_bag [ map { $_->id } @{ $self->bodies } ],
                [ $body_cherwell->id, $body_oxf->id ],
                'Sender should have both bodies';

            like $h->{bodies_name}, qr/Cherwell.*Oxfordshire/,
                'bodies_name for email should contain both bodies';

            $hits++;
            $self->success(1);
            return 0;
        },
    );

    my ($report_for_staging) = $mech->create_problems_for_body(
        1,
        ( join ',', $body_oxf->id, $body_cherwell->id ),
        'Test staging send',
        {   cobrand  => 'fixmystreet',
            category => 'Other',
            user     => $user,
        },
    );

    test_send(0);
    $report_for_staging->discard_changes;

    is $hits, 1, 'Email sender hit once';

    is $report_for_staging->send_fail_reason, undef,
        'send_fail_reason should be undef';
    is $report_for_staging->send_method_used, 'Email',
        'send_method should be email';
    cmp_bag $report_for_staging->send_fail_body_ids, [],
        'there should be no send_fail_body_ids';
};

sub test_send {
    my $send_reports = shift // 1;

    FixMyStreet::override_config {
        STAGING_FLAGS    => { send_reports => $send_reports },
        ALLOWED_COBRANDS => ['fixmystreet'],
        MAPIT_URL        => 'http://mapit.uk/',
        },
        sub {
        # Debug mode so we can attempt sending of same report within 5 min
        # window
        FixMyStreet::Script::Reports::send( 0, 0, 1 );
        };
}

done_testing();
