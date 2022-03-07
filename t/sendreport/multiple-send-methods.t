use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Test::Deep;
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('user@example.com');

my $body_oxf = $mech->create_body_ok( 2237, 'Oxfordshire County Council' );
my $body_cherwell
    = $mech->create_body_ok( 2419, 'Cherwell District Council' );

my $contact_oxf = $mech->create_contact_ok(
    body_id  => $body_oxf->id,
    category => 'Other',
    email    => 'other@oxfordshire.com',
);
my $contact_cherwell = $mech->create_contact_ok(
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

$body_oxf->update(
    {   send_method  => 'Open311',
        endpoint     => 'http://endpoint.example.com',
        jurisdiction => 'FMS',
        api_key      => 'test',
    },
);

my $mock_email   = Test::MockModule->new('FixMyStreet::SendReport::Email');
my $mock_open311 = Test::MockModule->new('FixMyStreet::SendReport::Open311');

subtest '1st attempt - email and Open311 both fail' => sub {
    $mock_email->mock(
        'send',
        sub {
            shift->error('Email fail');
            return -1;
        }
    );
    $mock_open311->mock(
        'send',
        sub {
            shift->error('Open311 fail');
            return -1;
        }
    );
    test_send();
    $report->discard_changes;

    is $report->whensent,         undef, 'whensent not recorded';
    is $report->send_method_used, undef, 'send_method_used not recorded';
    is $report->external_id,      undef, 'Report has no external ID';

    ok $report->send_fail_timestamp, 'send_fail_timestamp recorded';
    is $report->send_fail_count, 1, 'send_fail_count recorded';
    like $report->send_fail_reason, qr/Email fail/;
    like $report->send_fail_reason, qr/Open311 fail/,
        'send_fail_reason recorded';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id, $body_cherwell->id ],
        'Failed body ID saved for each body';
};

subtest '2nd attempt - email and Open311 both fail again' => sub {
    $mock_email->mock(
        'send',
        sub {
            shift->error('Email fail');
            return -1;
        }
    );
    $mock_open311->mock(
        'send',
        sub {
            shift->error('Open311 fail');
            return -1;
        }
    );
    test_send();
    $report->discard_changes;

    is $report->whensent,         undef, 'whensent not recorded';
    is $report->send_method_used, undef, 'send_method_used not recorded';
    is $report->external_id,      undef, 'Report has no external ID';

    is $report->send_fail_count, 2, 'send_fail_count updated';
    like $report->send_fail_reason, qr/Email fail/;
    like $report->send_fail_reason, qr/Open311 fail/,
        'send_fail_reason stays the same';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id, $body_cherwell->id ],
        'send_fail_body_ids remain the same';
};

subtest '3rd attempt - email succeeds, Open311 fails' => sub {
    $mock_email->unmock('send');
    $mock_open311->mock(
        'send',
        sub {
            shift->error('Open311 fail');
            return -1;
        }
    );
    test_send();
    $report->discard_changes;

    ok $report->whensent, 'whensent recorded';
    is $report->send_method_used, 'Email', 'send_method_used recorded';
    is $report->external_id,      undef,   'Report has no external ID';

    is $report->send_fail_count, 3, 'send_fail_count incremented';
    like $report->send_fail_reason, qr/Open311 fail/;
    unlike $report->send_fail_reason, qr/Email fail/,
        'email removed from send_fail_reason';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id ],
        'Failed body ID removed for Cherwell (email)';
};

subtest '4th attempt - Open311 fails, email set to fail again' => sub {
    # Since email was successful before, it should not be attempted again
    $mock_email->mock(
        'send',
        sub {
            shift->error('Email fail');
            return -1;
        }
    );
    $mock_open311->mock(
        'send',
        sub {
            shift->error('Open311 fail');
            return -1;
        }
    );
    test_send();
    $report->discard_changes;

    is $report->send_method_used, 'Email', 'send_method_used unchanged';
    is $report->external_id,      undef,   'Report has no external ID';

    is $report->send_fail_count, 4, 'send_fail_count incremented';
    like $report->send_fail_reason, qr/Open311 fail/;
    unlike $report->send_fail_reason, qr/Email fail/,
        'email not added to send_fail_reason';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id ],
        'Failed body ID not added again for Cherwell (email)';
};

subtest '5th attempt - both methods set to succeed' => sub {
    $mock_email->unmock('send');
    $mock_open311->unmock('send');
    test_send();
    $report->discard_changes;

    is $report->send_method_used, 'Email,Open311',
        'send_method_used includes Open311';
    is $report->external_id, 248, 'Report has external ID';

    is $report->send_fail_count,  4,     'send_fail_count unchanged';
    is $report->send_fail_reason, undef, 'send_fail_reason unset';
    cmp_bag $report->send_fail_body_ids, [], 'No send_fail_body_ids';
};

subtest 'Test resend' => sub {
    $mock_open311->mock(
        'send',
        sub {
            shift->error('Open311 fail');
            return -1;
        }
    );

    my ($report_for_resend) = $mech->create_problems_for_body(
        1,
        ( join ',', $body_oxf->id, $body_cherwell->id ),
        'Test resend',
        {   cobrand  => 'fixmystreet',
            category => 'Other',
            user     => $user,
        },
    );

    # Send report; we expect failure for Open311
    test_send();
    $report_for_resend->discard_changes;

    ok $report_for_resend->whensent, 'whensent recorded';
    is $report_for_resend->send_method_used, 'Email',
        'send_method_used recorded';

    is $report_for_resend->send_fail_count, 1, 'send_fail_count recorded';
    is $report_for_resend->send_fail_reason, 'Open311 fail',
        'send_fail_reason recorded';
    cmp_bag $report_for_resend->send_fail_body_ids, [ $body_oxf->id ],
        'Failed body ID recorded';

    # Call 'resend'; we expect certain fields to be unset
    $report_for_resend->resend;
    $report_for_resend->update;

    is $report_for_resend->whensent,         undef, 'whensent unset';
    is $report_for_resend->send_method_used, undef, 'send_method_used unset';

    is $report_for_resend->send_fail_count,  1, 'send_fail_count unmodified';
    is $report_for_resend->send_fail_reason, 'Open311 fail',
        'send_fail_reason unmodified';
    cmp_bag $report_for_resend->send_fail_body_ids, [],
        'send_fail_body_ids unset';
};

sub test_send {
    FixMyStreet::override_config {
        STAGING_FLAGS    => { send_reports => 1 },
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
