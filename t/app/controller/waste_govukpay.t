use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;

# Test the GOVUKPay cobrand role through the Waste controller.
#
# We reuse the Brent cobrand infrastructure (Echo integration, garden waste
# forms, contacts) but override its SCP payment methods with the GOVUKPay
# role implementations.  This exercises the full payment flow:
#   new subscription → payment redirect → pay_complete → confirmation

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

set_fixed_time('2023-01-09T17:00:00Z');

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2488, 'Brent', { cobrand => 'brent' });
my $user = $mech->create_user_ok('govukpay-test@example.net', name => 'Test User');

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(
        body  => $body,
        %$params,
        group => ['Waste'],
        extra => { type => 'waste' },
    );
    $contact->set_extra_fields(
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id',  required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact(
    { category => 'Garden Subscription', email => 'garden@example.com' },
    { code => 'Request_Type',                        required => 1, automated => 'hidden_field' },
    { code => 'Paid_Collection_Container_Type',      required => 1, automated => 'hidden_field' },
    { code => 'Paid_Collection_Container_Quantity',  required => 1, automated => 'hidden_field' },
    { code => 'Container_Type',                      required => 0, automated => 'hidden_field' },
    { code => 'Container_Quantity',                   required => 0, automated => 'hidden_field' },
    { code => 'Payment_Value',                        required => 1, automated => 'hidden_field' },
    { code => 'current_containers',                   required => 1, automated => 'hidden_field' },
    { code => 'new_containers',                       required => 1, automated => 'hidden_field' },
    { code => 'payment',                              required => 1, automated => 'hidden_field' },
    { code => 'payment_method',                       required => 1, automated => 'hidden_field' },
    { code => 'email_renewal_reminders_opt_in',       required => 0, automated => 'hidden_field' },
);

# Suppress SOAP::Result used by some Echo mock paths
package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

# --- Echo service data ---

sub food_waste_collection {
    return {
        Id        => 1001,
        ServiceId => 316,
        ServiceName => 'Food waste collection',
        ServiceTasks => { ServiceTask => {
            Id         => 400,
            TaskTypeId => 1688,
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                Allocation => {
                    RoundName      => 'Monday ',
                    RoundGroupName => 'Delta 04 Week 2',
                },
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate   => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate  => { DateTime => '2020-06-02T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    CurrentScheduledDate  => { DateTime => '2020-05-18T00:00:00Z' },
                    Ref => { Value => { anyType => [ 456, 789 ] } },
                },
            } ] },
        } },
    };
}

sub garden_waste_no_bins {
    return [
        food_waste_collection(),
        {
            Id          => 1002,
            ServiceId   => 317,
            ServiceName => 'Garden waste collection',
            ServiceTasks => '',
        },
    ];
}

# --- Override Brent's SCP payment methods with GOVUKPay ---

require FixMyStreet::Roles::Cobrand::GOVUKPay;

my $cobrand_mock = Test::MockModule->new('FixMyStreet::Cobrand::Brent');
for my $method (qw(
    waste_cc_has_redirect
    waste_cc_get_redirect_url
    waste_cc_check_payment_status
    cc_check_payment_status
    cc_check_payment_and_update
    _govukpay_config
    _govukpay_client
)) {
    my $code = FixMyStreet::Roles::Cobrand::GOVUKPay->can($method);
    $cobrand_mock->mock($method, $code) if $code;
}

# GOVUKPay requires waste_cc_payment_reference (SCP uses a different set)
$cobrand_mock->mock('waste_cc_payment_reference', sub {
    my ($self, $p) = @_;
    return 'FMS-' . $p->id;
});

# --- Mock Integrations::GOVUKPay API calls ---

my $sent_create_params;

my $govukpay = Test::MockModule->new('Integrations::GOVUKPay');
$govukpay->mock('create_payment', sub {
    my ($self, $args) = @_;
    $sent_create_params = $args;
    return {
        payment_id => 'govukpay_abc123',
        next_url   => 'http://example.org/faq',
    };
});

my $payment_status = 'success';
$govukpay->mock('get_payment_details', sub {
    my ($self, $payment_id) = @_;
    return {
        payment_id => $payment_id,
        amount     => $sent_create_params->{amount} || 5000,
        reference  => $sent_create_params->{reference} || 'FMS-0',
        state      => {
            status   => $payment_status,
            finished => ($payment_status eq 'success' ? \1 : \0),
        },
    };
});

# Suppress syslog from the integration module
my $syslog_mock = Test::MockModule->new('FixMyStreet::Roles::Syslog');
$syslog_mock->mock('log', sub {});

# --- Mock Echo integration ---

my $echo = Test::MockModule->new('Integrations::Echo');
$echo->mock('GetEventsForObject', sub { [] });
$echo->mock('GetTasks', sub { [] });
$echo->mock('FindPoints', sub { [
    {
        Description => '2 Example Street, Brent, HA0 5HF',
        Id          => '12345',
        SharedRef   => { Value => { anyType => 1000000002 } },
    },
] });
$echo->mock('GetPointAddress', sub {
    return {
        Id          => 12345,
        SharedRef   => { Value => { anyType => '1000000002' } },
        PointType   => 'PointAddress',
        PointAddressType => { Name => 'House' },
        Coordinates => { GeoPoint => { Latitude => 51.55904, Longitude => -0.28168 } },
        Description => '2 Example Street, Brent, ',
    };
});
$echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);

# --- Tests ---

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL        => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { brent => { url => 'http://example.org' } },
        waste => { brent => 1 },
        payment_gateway => { brent => {
            ggw_cost                   => 5000,
            govukpay_api_key           => 'test_govukpay_key_abc123',
            govukpay_api_url           => 'https://publicapi.payments.service.gov.uk',
            govukpay_description_prefix => 'Brent Council',
        } },
        waste_features => { brent => {
            dd_disabled => 1,
        } },
        anonymous_account => { brent => 'anonymous.customer' },
    },
}, sub {

    subtest 'GOVUKPay: new garden subscription via credit card' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted  => 1,
            name         => 'Test McTest',
            email        => 'govukpay-test@example.net',
        } });
        $mech->content_contains('£50.00', 'shows correct cost');
        $mech->content_contains('Continue to payment');

        # Submit form — should redirect to GOV.UK Pay hosted page
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        # Verify the payment creation request
        is $sent_create_params->{amount}, 5000, 'correct amount sent to GOV.UK Pay';
        like $sent_create_params->{reference}, qr/^FMS-\d+$/, 'reference follows expected format';
        like $sent_create_params->{description}, qr/Brent Council/, 'description includes council prefix';
        is $sent_create_params->{email}, 'govukpay-test@example.net', 'email forwarded to GOV.UK Pay';
        like $sent_create_params->{return_url}, qr{/waste/pay_complete/\d+/}, 'return_url points to pay_complete';

        # Extract report from the return URL sent to GOV.UK Pay
        my ($token, $report, $report_id) = get_report_from_redirect($sent_create_params->{return_url});
        ok $report, 'report created';

        # Check report state before payment confirmation
        is $report->state, 'unconfirmed', 'report unconfirmed before payment';
        is $report->category, 'Garden Subscription', 'correct category';
        is $report->title, 'Garden Subscription - New', 'correct title';
        is $report->get_extra_metadata('scpReference'), 'govukpay_abc123',
            'scpReference stored in report metadata';
        is $report->get_extra_field_value('payment_method'), 'credit_card',
            'payment method is credit_card';
        is $report->get_extra_field_value('payment'), 5000, 'payment amount on report';

        # Simulate return from GOV.UK Pay — payment successful
        $payment_status = 'success';
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        # Check report state after payment confirmation
        $report->discard_changes;
        is $report->state, 'confirmed', 'report confirmed after successful payment';
        is $report->get_extra_metadata('payment_reference'), 'govukpay_abc123',
            'payment_reference metadata set';
    };

    subtest 'GOVUKPay: pay_complete with failed payment' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted  => 1,
            name         => 'Test McTest',
            email        => 'govukpay-test@example.net',
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ($token, $report, $report_id) = get_report_from_redirect($sent_create_params->{return_url});
        ok $report, 'report created for failed payment test';

        # Simulate return from GOV.UK Pay — payment failed
        $payment_status = 'failed';
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        $report->discard_changes;
        is $report->state, 'unconfirmed', 'report stays unconfirmed on failed payment';

        # Restore for subsequent tests
        $payment_status = 'success';
    };

    subtest 'GOVUKPay: pay_complete with invalid token returns 404' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted  => 1,
            name         => 'Test McTest',
            email        => 'govukpay-test@example.net',
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ($token, $report, $report_id) = get_report_from_redirect($sent_create_params->{return_url});

        $mech->get("/waste/pay_complete/$report_id/WRONG_TOKEN");
        ok !$mech->res->is_success(), 'bad token rejects request';
        is $mech->res->code, 404, 'returns 404 for wrong token';
    };

    subtest 'GOVUKPay: pay_complete with in-progress payment' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted  => 1,
            name         => 'Test McTest',
            email        => 'govukpay-test@example.net',
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ($token, $report, $report_id) = get_report_from_redirect($sent_create_params->{return_url});

        # Simulate return when payment is still in progress
        $payment_status = 'submitted';
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        $report->discard_changes;
        is $report->state, 'unconfirmed', 'report stays unconfirmed while in progress';

        $payment_status = 'success';
    };

    subtest 'GOVUKPay: metadata passed to API includes report_id' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted  => 1,
            name         => 'Test McTest',
            email        => 'govukpay-test@example.net',
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        ok $sent_create_params->{metadata}, 'metadata sent to GOV.UK Pay';
        ok $sent_create_params->{metadata}{report_id}, 'report_id in metadata';
        is $sent_create_params->{metadata}{category}, 'Garden Subscription',
            'category in metadata';
    };
};

sub get_report_from_redirect {
    my $url = shift;
    my ($report_id, $token) = ($url =~ m#/(\d+)/([^/]+)$#);
    my $new_report = FixMyStreet::DB->resultset('Problem')->find({
        id => $report_id,
    });
    return undef unless $new_report
        && $new_report->get_extra_metadata('redirect_id') eq $token;
    return ($token, $new_report, $report_id);
}

done_testing;
