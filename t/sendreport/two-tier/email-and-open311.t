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
    body_id  => $body_oxf->id,
    category => 'Other',
    email    => 'other@oxfordshire.com',
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

$body_oxf->update(
    {   send_method  => 'Open311',
        endpoint     => 'http://endpoint.example.com',
        jurisdiction => 'FMS',
        api_key      => 'test',
    },
);

my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('fixmystreet')->new;
$report->result_source->schema->cobrand($cobrand);

my $mock_email   = Test::MockModule->new('FixMyStreet::SendReport::Email');
my $mock_open311 = Test::MockModule->new('FixMyStreet::SendReport::Open311');

sub mock_success {
    my $hits_ref = shift;
    return sub {
        my ($self, $row, $h) = @_;
        $$hits_ref++;
        $row->discard_changes;
        $self->success(1);
        return 0;
    };
}

sub mock_fail {
    my ($hits_ref, $error_msg) = @_;
    return sub {
        my ($self, $row, $h) = @_;
        $$hits_ref++;
        $row->discard_changes;
        $self->error($error_msg);
        return -1;
    };
}

sub mock_email_success { mock_success(@_) }
sub mock_email_fail { mock_fail($_[0], 'Email fail') }
sub mock_open311_success { mock_success(@_) }
sub mock_open311_fail { mock_fail($_[0], 'Open311 fail') }

subtest '1st attempt - email and Open311 both fail' => sub {
    is $report->duration_string, undef,
        'duration string is undef before any sending attempt';

    my ( $hits_email, $hits_open311 );
    $mock_email->mock('send', mock_email_fail(\$hits_email));
    $mock_open311->mock('send', mock_open311_fail(\$hits_open311));
    test_send();
    $report->discard_changes;

    is $hits_email,   1, 'Email sender hit once';
    is $hits_open311, 1, 'Open311 sender hit once';

    is $report->whensent,         undef, 'whensent not recorded';
    is $report->send_method_used, undef, 'send_method_used not recorded';

    ok $report->send_fail_timestamp, 'send_fail_timestamp recorded';
    is $report->send_fail_count, 1, 'send_fail_count recorded';
    like $report->send_fail_reason, qr/Email fail/;
    like $report->send_fail_reason, qr/Open311 fail/,
        'send_fail_reason recorded';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id, $body_cherwell->id ],
        'Failed body ID saved for each body';

    is $report->body(1), '', 'no body for duration_string';
};

subtest '2nd attempt - email and Open311 both fail again' => sub {
    my ( $hits_email, $hits_open311 );
    $mock_email->mock('send', mock_email_fail(\$hits_email));
    $mock_open311->mock('send', mock_open311_fail(\$hits_open311));
    test_send();
    $report->discard_changes;

    is $hits_email,   1, 'Email sender hit once';
    is $hits_open311, 1, 'Open311 sender hit once';

    is $report->whensent,         undef, 'whensent not recorded';
    is $report->send_method_used, undef, 'send_method_used not recorded';

    is $report->send_fail_count, 2, 'send_fail_count updated';
    like $report->send_fail_reason, qr/Email fail/;
    like $report->send_fail_reason, qr/Open311 fail/,
        'send_fail_reason stays the same';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id, $body_cherwell->id ],
        'send_fail_body_ids remain the same';

    is $report->body(1), '', 'no body for duration_string';
};

subtest '3rd attempt - email succeeds, Open311 fails' => sub {
    my ( $hits_email, $hits_open311 );
    $mock_email->mock('send', mock_email_success(\$hits_email));
    $mock_open311->mock('send', mock_open311_fail(\$hits_open311));
    test_send();
    $report->discard_changes;

    is $hits_email,   1, 'Email sender hit once';
    is $hits_open311, 1, 'Open311 sender hit once';

    ok $report->whensent, 'whensent recorded';
    is $report->send_method_used, 'Email', 'send_method_used recorded';

    is $report->send_fail_count, 3, 'send_fail_count incremented';
    like $report->send_fail_reason, qr/Open311 fail/;
    unlike $report->send_fail_reason, qr/Email fail/,
        'email removed from send_fail_reason';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id ],
        'Failed body ID removed for Cherwell (email)';

    is $report->body(1), 'Cherwell District Council',
        'Cherwell body for duration_string';
};

subtest '4th attempt - Open311 fails, email set to fail again' => sub {
    # Since email was successful before, it should not be attempted again
    my ( $hits_email, $hits_open311 );
    $mock_email->mock('send', mock_email_fail(\$hits_email));
    $mock_open311->mock('send', mock_open311_fail(\$hits_open311));
    test_send();
    $report->discard_changes;

    is $hits_email,   undef, 'Email sender not hit';
    is $hits_open311, 1,     'Open311 sender hit once';

    is $report->send_method_used, 'Email', 'send_method_used unchanged';

    is $report->send_fail_count, 4, 'send_fail_count incremented';
    like $report->send_fail_reason, qr/Open311 fail/;
    unlike $report->send_fail_reason, qr/Email fail/,
        'email not added to send_fail_reason';
    cmp_bag $report->send_fail_body_ids,
        [ $body_oxf->id ],
        'Failed body ID not added again for Cherwell (email)';

    is $report->body(1), 'Cherwell District Council',
        'Cherwell body for duration_string';
};

subtest '5th attempt - both methods set to succeed' => sub {
    my ( $hits_email, $hits_open311 );
    $mock_email->mock('send', mock_email_success(\$hits_email));
    $mock_open311->mock('send', mock_open311_success(\$hits_open311));
    test_send();
    $report->discard_changes;

    is $hits_email,   undef, 'Email sender not hit';      # successful before
    is $hits_open311, 1,     'Open311 sender hit once';

    is $report->send_method_used, 'Email,Open311',
        'send_method_used includes Open311';

    is $report->send_fail_count, 4, 'send_fail_count unchanged';
    is $report->send_fail_reason, 'Open311 fail',
        'send_fail_reason unchanged';
    cmp_bag $report->send_fail_body_ids, [], 'No send_fail_body_ids';

    is $report->body(1),
        'Cherwell District Council and Oxfordshire County Council',
        'Both bodies for duration_string';
};

subtest 'Test resend' => sub {
    # Call 'resend'; we expect certain fields to be unset
    $report->resend;
    $report->update;

    is $report->whensent,         undef, 'whensent unset';
    is $report->send_method_used, undef, 'send_method_used unset';

    is $report->send_fail_count, 4, 'send_fail_count unchanged';
    is $report->send_fail_reason, 'Open311 fail',
        'send_fail_reason unchanged';
    cmp_bag $report->send_fail_body_ids, [], 'send_fail_body_ids unset';

    is $report->body(1),
        'Cherwell District Council and Oxfordshire County Council',
        'Both bodies for duration_string';

    my ( $hits_email, $hits_open311 );
    $mock_email->mock('send', mock_email_success(\$hits_email));
    $mock_open311->mock('send', mock_open311_success(\$hits_open311));
    test_send();
    $report->discard_changes;

    is $hits_email,   1, 'Email sender hit once';
    is $hits_open311, 1, 'Open311 sender hit once';

    is $report->send_method_used, 'Open311,Email',
        'send_method_used includes both methods';

    is $report->send_fail_count, 4, 'send_fail_count unchanged';
    is $report->send_fail_reason, 'Open311 fail',
        'send_fail_reason unchanged';
    cmp_bag $report->send_fail_body_ids, [], 'No send_fail_body_ids';

    is $report->body(1),
        'Cherwell District Council and Oxfordshire County Council',
        'Both bodies for duration_string';
};

subtest 'Test staging send' => sub {
    # Will send with send_reports flag set to 0, so email will be used
    # instead of Open311

    my ( $hits_email, $hits_open311 );
    $mock_email->mock(
        send => sub {
            my ( $self, undef, $h ) = @_;
            like $h->{bodies_name}, qr/Cherwell.*Oxfordshire/,
                'bodies_name for email should contain both bodies';
            $hits_email++;
            $self->success(1);
            return 0;
        },
    );
    $mock_open311->mock('send', mock_open311_fail(\$hits_open311));

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

    is $hits_email,   1,     'Email sender hit once';
    is $hits_open311, undef, 'Open311 sender not hit';

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
