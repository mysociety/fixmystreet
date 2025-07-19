use FixMyStreet::TestMech;
use DateTime;
use Test::Output;
use Test::MockModule;
use JSON::MaybeXS;

use_ok 'FixMyStreet::Script::Bexley::CancelGardenWaste';

my $mech = FixMyStreet::TestMech->new;
my $area_id = 2494;
my $body = $mech->create_body_ok($area_id, 'Bexley Council', {
    cobrand => 'bexley',
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
                { UPRN => '123456789' },
                { UPRN => '987654321' },
            ];

            my $cancel_calls = [];
            my $canceller_test = FixMyStreet::Script::Bexley::CancelGardenWaste->new(
                cobrand => $cobrand,
                verbose => 1,
            );

            # Mock cancel_by_uprn to track calls
            my $cancel_mock = Test::MockModule->new('FixMyStreet::Script::Bexley::CancelGardenWaste');
            $cancel_mock->mock('cancel_by_uprn', sub {
                my ($self, $uprn) = @_;
                push @$cancel_calls, $uprn;
            });

            stdout_is { $canceller_test->cancel_from_api(7) }
                "Found 2 cancellations\n",
                "Correct number of cancellations found";

            is_deeply $cancel_calls, ['123456789', '987654321'],
                "cancel_by_uprn called for each UPRN";
        };
    };

    subtest 'cancel_by_uprn tests' => sub {
        my $canceller = FixMyStreet::Script::Bexley::CancelGardenWaste->new(
            cobrand => $cobrand,
            verbose => 1,
        );

        my $uprn = '123456789';

        subtest 'no active subscription found' => sub {
            stdout_is { $canceller->cancel_by_uprn($uprn) }
                "Attempting to cancel subscription for UPRN $uprn\n" .
                "  No active garden subscription found for UPRN $uprn\n",
                "Handles no active subscription correctly";
        };

        subtest 'handles direct debit cancellation' => sub {
            my $uprn = '111222333';

            # Create an active garden subscription with direct debit
            my ($garden_report) = $mech->create_problems_for_body(1, $body->id, 'Garden Subscription - New', {
                category => 'Garden Subscription',
            });
            $garden_report->set_extra_metadata('uprn', $uprn);
            $garden_report->set_extra_metadata('payment_method', 'direct_debit');
            $garden_report->set_extra_metadata('direct_debit_contract_id', 'PAYER123');
            $garden_report->update;

            my $dd_integration_mock_obj = Test::MockModule->new('Integrations::Agile');
            $dd_integration_mock_obj->mock('cancel_plan', sub {
                my ($self, $args) = @_;
                is $args->{report}->id, $garden_report->id, 'Correct report passed';
                return 1;
            });

            stdout_like { $canceller->cancel_by_uprn($uprn) }
                qr/Attempting to cancel subscription for UPRN $uprn.*Found active report.*Cancelling Direct Debit.*Successfully sent cancellation request/s,
                "Successfully handles direct debit cancellation";
        };
    };
};

done_testing;
