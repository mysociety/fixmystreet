use DateTime;
use FixMyStreet::TestMech;
use JSON::MaybeXS;
use Test::Deep;
use Test::MockModule;
use Test::Output;
use t::Mock::Bexley;

use_ok 'FixMyStreet::Script::Bexley::CancelGardenWaste';

my $mech = FixMyStreet::TestMech->new;

my $comment_user = FixMyStreet::DB->resultset('User')
    ->create( { email => 'comment@example.com', name => 'Comment User' } );

my $area_id = 2494;
my $body = $mech->create_body_ok($area_id, 'Bexley Council', {
    cobrand => 'bexley',
    comment_user_id => $comment_user->id,
});

# Create test contacts
my $garden_contact = $mech->create_contact_ok(
    category => 'Garden Subscription',
    body_id => $body->id,
    email => 'garden@example.com'
);

my $cancel_contact = $mech->create_contact_ok(
    category => 'Cancel Garden Subscription',
    body_id => $body->id,
    email => 'cancel@example.com'
);

# Create test user
my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

# Mock the Agile integration
my $agile_mock = Test::MockModule->new('Integrations::Agile');
my $agile_response;
$agile_mock->mock('LastCancelled', sub { return $agile_response });

# Mock APS integration
my $access_mock = Test::MockModule->new('Integrations::AccessPaySuite');
$access_mock->mock( 'call', sub { return {} } );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['bexley'],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        agile => {
            bexley => {
                url => 'http://example.com/agile',
            },
        },
    },
}, sub {
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('bexley')->new;

    subtest 'cancel_from_api tests' => sub {
        my $canceller = FixMyStreet::Script::Bexley::CancelGardenWaste->new(
            cobrand => $cobrand,
            verbose => 0,
        );

        subtest 'handles API error' => sub {
            $agile_response = { error => 'API Error' };

            my $result;
            stderr_is { $result = $canceller->cancel_from_api(7) }
                "Error fetching cancellations: API Error\n",
                "API error is reported";

            is $result, undef, "Returns undef on API error";
        };

        subtest 'handles empty response' => sub {
            $agile_response = [];

            my $canceller_verbose = FixMyStreet::Script::Bexley::CancelGardenWaste->new(
                cobrand => $cobrand,
                verbose => 1,
            );

            stdout_is { $canceller_verbose->cancel_from_api(7) }
                "No cancellations found in the last 7 days\n",
                "Empty response handled correctly";
        };

        subtest 'processes cancellations' => sub {
            $agile_response = [
                { Reference => 'GW-SERV-001-12345' },
                { Reference => 'GW-SERV-001-54321' },
            ];

            my $cancel_calls = [];
            my $canceller_test = FixMyStreet::Script::Bexley::CancelGardenWaste->new(
                cobrand => $cobrand,
                verbose => 1,
            );

            # Mock cancel_contract to track calls
            my $cancel_mock = Test::MockModule->new('FixMyStreet::Script::Bexley::CancelGardenWaste');
            $cancel_mock->mock('cancel_contract', sub {
                my ($self, $contract) = @_;
                push @$cancel_calls, $contract->{Reference};
            });

            stdout_is { $canceller_test->cancel_from_api(7) }
                "Found 2 cancellations\n",
                "Correct number of cancellations found";

            is_deeply $cancel_calls, ['GW-SERV-001-12345', 'GW-SERV-001-54321'],
                "cancel_contract called for each Reference";
        };
    };

    subtest 'cancel_contract tests' => sub {
        my $canceller = FixMyStreet::Script::Bexley::CancelGardenWaste->new(
            cobrand => $cobrand,
            verbose => 1,
        );

        my $id = 42;
        my $uprn = '123456789';
        my $reference = 'GW-SERV-001-12345';

        my $contract = {
            Id => $id,
            UPRN => $uprn,
            Reference => $reference,
            Reason => 'Moved house',
        };

        subtest 'no active subscription found' => sub {
            stdout_is { $canceller->cancel_contract($contract) }
                "Attempting to cancel contract $reference (UPRN: $uprn)\n" .
                "  No active garden subscription found for Agile report $id ($reference)\n",
                "Handles no active subscription correctly (UPRN with no legacy contracts)";
        };

        subtest 'finds report by Agile reference (new subscription)' => sub {
            my $garden_report = _create_report( uprn => $uprn, external_id => "Agile-$reference" );

            $access_mock->mock('cancel_plan', sub {
                my ($self, $args) = @_;
                is $args->{report}->id, $garden_report->id, 'Correct report passed (matched by Agile Reference)';
                return 1;
            });

            stdout_like { $canceller->cancel_contract($contract) }
                qr/Attempting to cancel contract $reference.*Found active report.*Cancelling Direct Debit.*Successfully sent cancellation request/s,
                "Finds report by Agile Reference (used for new subscriptions)";
        };

        subtest 'finds report by Agile Id (renewal)' => sub {
            $mech->delete_problems_for_body( $body->id );

            my $garden_report = _create_report( uprn => $uprn, external_id => "Agile-$id" );

            $access_mock->mock('cancel_plan', sub {
                my ($self, $args) = @_;
                is $args->{report}->id, $garden_report->id, 'Correct report passed (matched by Agile Id)';
                return 1;
            });

            stdout_like { $canceller->cancel_contract($contract) }
                qr/Attempting to cancel contract $reference.*Found active report.*Cancelling Direct Debit.*Successfully sent cancellation request/s,
                "Finds report by Agile Id (used for renewals)";
        };

        subtest 'handles legacy UPRN-based direct debit cancellation' => sub {
            $mech->delete_problems_for_body( $body->id );

            my $legacy_uprn = '20001';  # UPRN that has legacy contracts in mock
            my $legacy_contract = { %$contract, UPRN => $legacy_uprn };

            # No FMS report exists with the Agile external_id (legacy sub never had one)

            my $cancel_plan_called = 0;
            my $passed_contract_ids;

            $access_mock->mock('cancel_plan', sub {
                my ($self, $args) = @_;
                $cancel_plan_called = 1;
                ok !$args->{report}, 'No report passed for legacy-only cancellation';
                ok $args->{contract_ids}, 'contract_ids parameter provided for legacy subscription';
                $passed_contract_ids = $args->{contract_ids};
                return 1;  # Success
            });

            stdout_like { $canceller->cancel_contract($legacy_contract) }
                qr/Found 1 legacy contract.*Successfully sent cancellation request.*No active garden subscription/s,
                "Cancels legacy contracts even when no matching FMS report exists";

            ok $cancel_plan_called, 'cancel_plan was called';
            is_deeply $passed_contract_ids, ['TEST-CONTRACT-20001'],
                'Correct legacy contract ID passed from BexleyContracts lookup';
        };

        subtest 'archive_contract fails for single contract' => sub {
            $mech->delete_problems_for_body( $body->id );

            $access_mock->unmock('cancel_plan');
            $access_mock->mock(
                'archive_contract',
                sub {
                    { error => 'Archive failed' }
                }
            );

            _create_report( uprn => $uprn, external_id => "Agile-$reference" );

            stdout_like { $canceller->cancel_contract($contract) }
                qr/Attempting to cancel contract $reference.*Found active report.*Cancelling Direct Debit.*Failed to send cancellation request to Direct Debit provider for Agile reference $reference: Archive failed/s,
                "Reports failure when archive_contract fails for single contract";
        };

        subtest 'archive_contract fails for legacy contracts' => sub {
            $mech->delete_problems_for_body( $body->id );

            my $legacy_uprn = '20001';  # UPRN that has legacy contracts in mock
            my $legacy_contract = { %$contract, UPRN => $legacy_uprn };

            $access_mock->mock(
                'archive_contract',
                sub {
                    { error => 'Archive failed' }
                }
            );

            # No FMS report — legacy contracts are cancelled regardless
            stdout_like { $canceller->cancel_contract($legacy_contract) }
                qr/Attempting to cancel contract $reference.*Found 1 legacy contract.*Cancelling Direct Debit.*Successfully sent cancellation request.*No active garden subscription/s,
                "Cancels legacy contracts even when archive_contract errors are ignored";
        };

        subtest 'skips reports already cancelled' => sub {
            $mech->delete_problems_for_body( $body->id );

            my $garden_report = _create_report( uprn => $uprn, external_id => "Agile-$reference" );
            $garden_report->set_extra_metadata( direct_debit_cancellation_date => '2026-01-01T00:00:00' );
            $garden_report->update;

            my $cancel_plan_called = 0;
            $access_mock->mock( 'cancel_plan', sub { $cancel_plan_called = 1; return 1; } );

            stdout_like { $canceller->cancel_contract($contract) }
                qr/No active garden subscription found/,
                'falls through to no-active-subscription branch';

            ok !$cancel_plan_called, 'cancel_plan not called for already-cancelled report';
        };
    };
};

# Create an active garden subscription with direct debit
sub _create_report {
    my %args = @_;

    my $is_cancel = $args{is_cancel};
    my $skip_contract_id = $args{skip_contract_id};

    my ($garden_report) = $mech->create_problems_for_body(
        1, $body->id,
        '',
        {   category => $is_cancel
            ? 'Cancel Garden Subscription'
            : 'Garden Subscription',
            title => ( $is_cancel ? 'Garden Subscription - Cancel' : 'Garden Subscription - New' ),
            created => $args{created} || \'current_timestamp',
            external_id => $args{external_id},
            uprn => $args{uprn},
        },

    );
    $garden_report->set_extra_fields(
        { name => 'property_id', value => $args{uprn} },
        { name => 'payment_method', value => 'direct_debit' },
        { name => 'customer_external_ref', value => 'AGILE_CUSTOMER_REF' },
        { name => 'direct_debit_reference', value => 'DD_REF_123' },
        { name => 'not_used', value => 'IGNORE' },
    );
    $garden_report->set_extra_metadata('property_address', '123 Bexley St');
    unless ($skip_contract_id) {
        $garden_report->set_extra_metadata('direct_debit_contract_id', 'PAYER123');
        $garden_report->set_extra_metadata('direct_debit_customer_id', 'CUST123');
    }
    $garden_report->set_extra_metadata('not_used', 'IGNORE');
    $garden_report->update;

    return $garden_report;
}

sub _last_cancel_report {
    return FixMyStreet::DB->resultset('Problem')
        ->search( { category => 'Cancel Garden Subscription' } )
        ->order_by('-id')
        ->first;
}


done_testing;
