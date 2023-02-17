use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });
set_fixed_time('2023-01-09T17:00:00Z'); # Set a date when garden service full price for most tests

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2488, 'Brent', {}, { cobrand => 'brent' });
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $body, name => 'Staff User');
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_anonymous_user' });
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste'], extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Garden Subscription', email => 'garden@example.com'},
    { code => 'Request_Type', required => 1, automated => 'hidden_field' },
    { code => 'Paid_Collection_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Paid_Collection_Container_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 0, automated => 'hidden_field' },
    { code => 'Container_Quantity', required => 0, automated => 'hidden_field' },
    { code => 'Payment_Value', required => 1, automated => 'hidden_field' },
    { code => 'current_containers', required => 1, automated => 'hidden_field' },
    { code => 'new_containers', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
);

create_contact({ category => 'Amend Garden Subscription', email => 'garden@example.com'},
    { code => 'Additional_Collection_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Additional_Collection_Container_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 0, automated => 'hidden_field' },
    { code => 'Container_Quantity', required => 0, automated => 'hidden_field' },
    { code => 'System Notes', required => 0, automated => 'hidden_field' },
    { code => 'Paid_Collection_Container_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Payment_Value', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
);

create_contact({ category => 'Cancel Garden Subscription', email => 'garden@example.com'},
    { code => 'End_Date', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
);

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

sub garden_waste_no_bins {
    return [ {
        Id => 1001,
        ServiceId => 316,
        ServiceName => 'Food waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 400,
            TaskTypeId => 1688,
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                ScheduleDescription => 'every other Monday',
                Allocation => {
                    RoundName => 'Monday ',
                    RoundGroupName => 'Delta 04 Week 2',
                },
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-02T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    Ref => { Value => { anyType => [ 456, 789 ] } },
                },
            } ] },
        } },
    }, {
        # Eligibility for garden waste, but no task
        Id => 1002,
        ServiceId => 317,
        ServiceName => 'Garden waste collection',
        ServiceTasks => ''
    } ];
}

sub garden_waste_one_sack {
    my $refuse_bin = garden_waste_no_bins();
    my $garden_bin = _garden_waste_service_units(1, 'sack');
    return [ $refuse_bin->[0], $garden_bin->[0] ];
}

sub garden_waste_one_bin {
    my $refuse_bin = garden_waste_no_bins();
    my $garden_bin = _garden_waste_service_units(1, 'bin');
    return [ $refuse_bin->[0], $garden_bin->[0] ];
}

sub garden_waste_two_bins {
    my $refuse_bin = garden_waste_no_bins();
    my $garden_bin = _garden_waste_service_units(2, 'bin');
    return [ $refuse_bin->[0], $garden_bin->[0] ];
}

sub _garden_waste_service_units {
    my ($bin_count, $type) = @_;

    if ($type eq 'sack') {
        $bin_count = 9;
    }

    my $bin_type_id = 1;

    return [ {
        Id => 1002,
        ServiceId => 317,
        ServiceName => 'Garden waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 405,
            TaskTypeId => 1689,
            Data => { ExtensibleDatum => [ {
                DatatypeName => 'BRT - Paid Collection Container Quantity',
                Value => $bin_count,
            }, {
                DatatypeName => 'BRT - Paid Collection Container Type',
                Value => $bin_type_id,
            } ] },
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                ScheduleDescription => 'every other Monday',
                Allocation => {
                    RoundName => 'Monday ',
                    RoundGroupName => 'Delta 04 Week 2',
                },
                StartDate => { DateTime => '2020-03-30T00:00:00Z' },
                EndDate => { DateTime => '2021-03-30T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                    Ref => { Value => { anyType => [ 567, 890 ] } },
                },
            } ] },
        } } } ];
}

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { brent => { url => 'http://example.org' } },
        waste => { brent => 1 },
        payment_gateway => { brent => {
            ggw_cost => 5000,
            cc_url => 'http://example.org/cc_submit',
            hmac => '1234',
            hmac_id => '1234',
            scpID => '1234',
            paye_hmac => '1234',
            paye_hmac_id => '1234',
            paye_siteID => '1234',
        } },
        waste_features => { brent => {text_for_waste_payment => 'Payment processed'} },
        anonymous_account => { brent => 'anonymous.customer' },
    },
}, sub {
    my ($p) = $mech->create_problems_for_body(1, $body->id, 'Garden Subscription - New', {
        user_id => $user->id,
        category => 'Garden Subscription',
        whensent => \'current_timestamp',
        send_state => 'sent',
    });
    $p->title('Garden Subscription - New');
    $p->update_extra_field({ name => 'property_id', value => 12345});
    $p->update;

    my $sent_params = {};
    my $call_params = {};

    my $pay = Test::MockModule->new('Integrations::SCP');
    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = { @_ };
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
        return {
            transactionState => 'IN_PROGRESS',
            scpReference => '12345',
            invokeResult => {
                status => 'SUCCESS',
                redirectUrl => 'http://example.org/faq'
            }
        };
    });
    $pay->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return {
            transactionState => 'COMPLETE',
            paymentResult => {
                status => 'SUCCESS',
                paymentDetails => {
                    paymentHeader => {
                        uniqueTranId => 54321
                    }
                }
            }
        };
    });

    my $paye = Test::MockModule->new('Integrations::Paye');
    $paye->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = { @_ };
    });
    $paye->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $paye->original('pay')->($self, $sent_params);
        return {
            transactionState => 'InProgress',
            apnReference => '4ab5f886-de7d-4f5b-bbd8-42151a5deb82',
            requestId => '21355',
            invokeResult => {
                status => 'Success',
                redirectUrl => 'http://paye.example.org/faq',
            }
        }
    });
    $paye->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return {
            transactionState => 'Complete',
            paymentResult => {
                status => 'Success',
                paymentDetails => {
                    authDetails => {
                        authCode => 'authCode',
                        uniqueAuthId => 54321,
                    },
                    payments => {
                        paymentSummary => {
                            continuousAuditNumber => 'CAN',
                        }
                    }
                }
            }
        };
    });

    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetEventsForObject', sub { [] });
    $echo->mock('GetTasks', sub { [] });
    $echo->mock('FindPoints', sub { [
        { Description => '1 Example Street, Brent, HA0 5HF', Id => '11345', SharedRef => { Value => { anyType => 1000000001 } } },
        { Description => '2 Example Street, Brent, HA0 5HF', Id => '12345', SharedRef => { Value => { anyType => 1000000002 } } },
        { Description => '3 Example Street, Brent, HA0 5HF', Id => '14345', SharedRef => { Value => { anyType => 1000000004 } } },
    ] });
    $echo->mock('GetPointAddress', sub {
        return {
            Id => 12345,
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.55904, Longitude => -0.28168 } },
            Description => '2 Example Street, Brent, ',
        };
    });

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_sack);
    subtest 'check sack subscription template change for sacks' => sub {
        set_fixed_time('2020-05-09T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('<dd class="govuk-summary-list__value">Sacks</dd>');
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'check sack subscription template does not affect normal bin count' => sub {
        set_fixed_time('2020-05-09T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('<dd class="govuk-summary-list__value">1 bin</dd>');
    };

    subtest 'check subscription link present' => sub {
        set_fixed_time('2021-03-09T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr#Renewal</dt>\s*<dd[^>]*>30 March 2021#m);
        $mech->content_lacks('Subscribe to Garden waste collection service', 'Subscribe link not present for active sub');
        set_fixed_time('2021-05-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Subscribe to Garden waste collection service', 'Subscribe link present if expired');
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);
    subtest 'check new sub bin limits' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes' } });
        $mech->content_contains('Please specify how many bins you already have');
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        my $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        is $mech->value('current_bins'), 0, "current bins is set to 0";

        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 1 } });
        $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        $mech->content_like(qr#Total to pay now: £<span[^>]*>50.00#, "initial cost set correctly");
        is $mech->value('current_bins'), 1, "current bins is set to 1";
    };

    for my $test (
        {
            month => '01',
            pounds_cost => '50.00',
            pence_cost => '5000'
        },
        {
            month => '10',
            pounds_cost => '25.00',
            pence_cost => '2500'
        }
    ) {

        subtest 'check new sub credit card payment' => sub {
            set_fixed_time("2021-$test->{month}-09T17:00:00Z");
            $mech->get_ok('/waste/12345/garden');
            $mech->submit_form_ok({ form_number => 1 });
            $mech->submit_form_ok({ with_fields => { existing => 'no' } });
            $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
            $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
            } });
            $mech->content_contains('Test McTest');
            $mech->content_contains('£' . $test->{pounds_cost});
            $mech->content_contains('1 bin');
            $mech->submit_form_ok({ with_fields => { goto => 'details' } });
            $mech->content_contains('<span id="cost_pa">' . $test->{pounds_cost});
            $mech->content_contains('<span id="cost_now">' . $test->{pounds_cost});
            $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
            } });
            # external redirects make Test::WWW::Mechanize unhappy so clone
            # the mech for the redirect
            my $mech2 = $mech->clone;
            $mech2->content_contains('Continue to payment', 'Waste features text_for_waste_payment not used for non-staff payment');
            $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

            is $mech2->res->previous->code, 302, 'payments issues a redirect';
            is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $sent_params->{items}[0]{amount}, $test->{pence_cost}, 'correct amount used';
            check_extra_data_pre_confirm($new_report, new_bin_type => 1, new_quantity => 1);

            $mech->get('/waste/pay/xx/yyyyyyyyyyy');
            ok !$mech->res->is_success(), "want a bad response";
            is $mech->res->code, 404, "got 404";
            $mech->get("/waste/pay_complete/$report_id/NOTATOKEN");
            ok !$mech->res->is_success(), "want a bad response";
            is $mech->res->code, 404, "got 404";
            $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");

            check_extra_data_post_confirm($new_report);

            $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

            FixMyStreet::Script::Reports::send();
            my @emails = $mech->get_email;
            my $body = $mech->get_text_body_from_email($emails[1]);
            like $body, qr/Number of bin subscriptions: 1/;
            like $body, qr/Bins to be delivered: 1/;
            like $body, qr/Total:.*?$test->{pounds_cost}/;
            $mech->clear_emails_ok;
        };
    }

    set_fixed_time('2023-01-09T17:00:00Z'); # Set a date when garden service full price for most tests

    subtest 'check new sub credit card payment with no bins required' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 1,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£50.00');

        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 5000, 'correct amount used';
        check_extra_data_pre_confirm($new_report, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        unlike $body, qr/Bins to be delivered/;
        like $body, qr/Total:.*?50.00/;
    };

    subtest 'check new sub credit card payment with one less bin required' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 2,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£50.00');

        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 5000, 'correct amount used';
        check_extra_data_pre_confirm($new_report, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be removed: 1/;
        like $body, qr/Total:.*?50.00/;
    };

    subtest 'check new staff subscription of sacks' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->submit_form_ok({ with_fields => {
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£50.00');
        $mech->content_contains('Payment processed');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech->res->previous->code, 302, 'payments issues a redirect';
        is $mech->res->previous->header('Location'), 'http://paye.example.org/faq?apnReference=4ab5f886-de7d-4f5b-bbd8-42151a5deb82', "redirects to payment gateway";

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 5000, 'correct amount used';
        check_extra_data_pre_confirm($report, new_bins => 0, bin_type => 2, ref_type => 'apn');
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        $report->discard_changes;
        is $report->get_extra_field_value('LastPayMethod'), 1, 'correct echo payment method field';
        is $report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
        is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Garden waste sack collection: 1/;
        like $body, qr/Total:.*?50.00/;
    };

    subtest 'cancel garden service' => sub {
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-03-09T17:00:00Z');
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->get_extra_field_value('End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->state, 'confirmed', 'report confirmed';

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);

        like $body, qr/You have cancelled your garden waste collection service/;
        unlike $body, qr/Number of bin subscriptions/;
        unlike $body, qr/Bins to be delivered/;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
    set_fixed_time('2021-03-09T17:00:00Z');

    subtest 'check renew staff subscription of sacks' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->submit_form_ok({ with_fields => {
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£50.00');
        $mech->content_contains('Payment processed');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech->res->previous->code, 302, 'payments issues a redirect';
        is $mech->res->previous->header('Location'), 'http://paye.example.org/faq?apnReference=4ab5f886-de7d-4f5b-bbd8-42151a5deb82', "redirects to payment gateway";

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 5000, 'correct amount used';
        check_extra_data_pre_confirm($report, type => 'Renew', new_bins => 0, bin_type => 2, ref_type => 'apn');
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        $report->discard_changes;
        is $report->get_extra_field_value('LastPayMethod'), 1, 'correct echo payment method field';
        is $report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
        is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Garden waste sack collection: 1/;
        like $body, qr/Total:.*?50.00/;
    };

    for my $test (
        {
            'bins_wanted' => 3,
            'container_type' => 1,
            'container_quantity' => 1,
        },
        {
            'bins_wanted' => 4,
            'container_type' => 1,
            'container_quantity' => 2,
        },
        {
            'bins_wanted' => 1,
            'container_type' => '',
            'container_quantity' => '',
        },
    ) {
        subtest 'check modifying Green Garden Waste as staff' => sub {
            $mech->log_in_ok($staff_user->email);
            set_fixed_time('2021-01-09T17:00:00Z'); # Before renewal is due so we can modify
            $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);
            $mech->get_ok('/waste/12345');
            $mech->content_contains('Modify your garden waste subscription');
            $mech->get_ok('/waste/12345/garden_modify');
            $mech->submit_form_ok({ with_fields => { task => 'modify' }}, 'Choose modify');
            $mech->submit_form_ok({ with_fields => {
                bins_wanted => $test->{bins_wanted},
                name => $user->name,
                email => $user->email
                } }, 'Request '. $test->{bins_wanted} . ' bins when currently have 2');
            $mech->submit_form_ok({ with_fields => { tandc => 1 }}, 'Submit request');
            my $report = FixMyStreet::DB->resultset('Problem')->find({category => 'Amend Garden Subscription'});
            is($report->get_extra_field_value('Container_Type'), $test->{container_type}, $test->{container_type} ? "Container Type is set to request delivery" : "Container Type is not set");
            is($report->get_extra_field_value('Container_Quantity'), $test->{container_quantity}, "Container Quantity is " . ($test->{container_quantity} ? $test->{container_quantity} : 'not set'));
            $report->delete;
        };
    };

    subtest 'check modifying Green Garden Waste not available for user' => sub {
            $mech->log_in_ok($user->email);
            set_fixed_time('2021-01-09T17:00:00Z'); # Before renewal is due so we can modify
            $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('Modify your garden waste subscription');
    };

    for my $test(
        {
            box_ticked => 1,
            cost => '£20.00',
            cost_pence => '2000',
            description => '20 per cent off half price with checkbox ticked',
            date => '2023-10-09T17:00:00Z',
        },
        {
            box_ticked => 1,
            cost => '£40.00',
            cost_pence => '4000',
            description => '20 per cent off with checkbox ticked',
            date => '2023-01-09T17:00:00Z',
        },
        {
            box_ticked => 0,
            cost => '£50.00',
            cost_pence => '5000',
            description => 'Full price with checkbox not ticked',
            date => '2023-01-09T17:00:00Z',
        }) {
            subtest 'check discount on new ggw can be applied by staff user' => sub {
                FixMyStreet::override_config {
                    ALLOWED_COBRANDS => 'brent',
                    MAPIT_URL => 'http://mapit.uk/',
                    STAGING_FLAGS => { skip_waste_payment => 1},
                    COBRAND_FEATURES => {
                        echo => { brent => { url => 'http://example.org' } },
                        waste => { brent => 1 },
                        waste_features => { brent => {
                            ggw_discount_as_percent => 20,
                            dd_disabled => 1,
                            text_for_waste_payment => 'Payment processed'
                            } },
                        payment_gateway => { brent => {
                            ggw_cost => 5000,
                            cc_url => 'http://example.org/cc_submit',
                            hmac => '1234',
                            hmac_id => '1234',
                            scpID => '1234',
                        }   },
                        anonymous_account => { brent => 'anonymous.customer' },
                },
            }, sub {
                set_fixed_time($test->{date});
                $mech->log_in_ok($staff_user->email);
                $mech->get_ok('/waste/12345/garden');
                $mech->submit_form_ok({ with_fields => { apply_discount => $test->{box_ticked} }}, 'Discount box available');
                $mech->submit_form_ok({ with_fields => { container_choice => 'bin' } });
                $mech->submit_form_ok({ with_fields => { existing => 'no' } });
                $mech->submit_form_ok({ with_fields => {
                    current_bins => 1,
                    bins_wanted => 1,
                    name => 'Test McTest',
                    email => 'test@example.net'
                } });
                $mech->content_contains('Test McTest');
                $mech->content_contains($test->{cost}, $test->{description});
                $mech->content_contains('Payment processed');
                $mech->submit_form_ok({ with_fields => { tandc => 1 } });
                my ($report_id) = $mech->content =~ /<strong>(\d+)<\/strong>/;
                my $report = FixMyStreet::DB->resultset('Problem')->find( {
                    id => $report_id,
                });
                is $report->get_extra_field_value('payment'), $test->{cost_pence}, 'Correct payment set on report';
                $mech->clear_emails_ok;
                FixMyStreet::Script::Reports::send();
                my @emails = $mech->get_email;
                my $body = $mech->get_text_body_from_email($emails[1]);
                like $body, qr /Total: $test->{cost}/, 'Email contains correct subscription';
            };
        };
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden');
        $mech->content_lacks('id="apply_discount', 'Discount not available for non-staff');
    };

    for my $test(
    {
        box_ticked => 1,
        cost => '£40.00',
        cost_pence => '4000',
        description => '20 per cent off with checkbox ticked',
    }) {
        subtest 'check discount on renew ggw can be applied by staff user' => sub {
            FixMyStreet::override_config {
                ALLOWED_COBRANDS => 'brent',
                MAPIT_URL => 'http://mapit.uk/',
                STAGING_FLAGS => { skip_waste_payment => 1},
                COBRAND_FEATURES => {
                    echo => { brent => { url => 'http://example.org' } },
                    waste => { brent => 1 },
                    waste_features => { brent => { ggw_discount_as_percent => 20, dd_disabled => 1 } },
                    payment_gateway => { brent => {
                    ggw_cost => 5000,
                    cc_url => 'http://example.org/cc_submit',
                    hmac => '1234',
                    hmac_id => '1234',
                    scpID => '1234',
                    }   },
                    anonymous_account => { brent => 'anonymous.customer' },
                },
            }, sub {
                $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
                set_fixed_time('2021-03-09T17:00:00Z');
                $mech->log_in_ok($staff_user->email);
                $mech->get_ok('/waste/12345/garden_renew');
                $mech->submit_form_ok({ with_fields => {
                    container_choice => 'bin',
                    apply_discount => 1,
                     } });
                $mech->content_contains('data-per_bin_cost="'. $test->{cost_pence} . '"', 'Correct per_bin_cost discount in template for waste.js calculations');
                $mech->content_contains('Total per year: £<span id="cost_pa">' . $test->{cost_pence} / 100, 'Correct discount in template before js calculations take over');
                $mech->submit_form_ok({ with_fields => {
                    current_bins => 1,
                    bins_wanted => 1,
                    name => 'Test McTest',
                    email => 'test@example.net',
                    } }), ;
                $mech->content_contains($test->{cost}, $test->{description});
                $mech->submit_form_ok({ with_fields => {
                    tandc => 1,
                    } });
                my ($report_id) = $mech->content =~ /<strong>(\d+)<\/strong>/;
                my $report = FixMyStreet::DB->resultset('Problem')->find( {
                     id => $report_id,
                });
                is $report->get_extra_field_value('payment'), $test->{cost_pence}, 'Correct payment set on report';
                $mech->clear_emails_ok;
                FixMyStreet::Script::Reports::send();
                my @emails = $mech->get_email;
                my $body = $mech->get_text_body_from_email($emails[1]);
                like $body, qr /Total: $test->{cost}/, 'Email contains correct subscription';
            };
        };
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->content_lacks('id="apply_discount', 'Discount not available for non-staff');
    };
};

sub get_report_from_redirect {
    my $url = shift;

    my ($report_id, $token) = ( $url =~ m#/(\d+)/([^/]+)$# );
    my $new_report = FixMyStreet::DB->resultset('Problem')->find( {
            id => $report_id,
    });

    return undef unless $new_report->get_extra_metadata('redirect_id') eq $token;
    return ($token, $new_report, $report_id);
}

sub check_extra_data_pre_confirm {
    my $report = shift;
    my %params = (
        type => 'New',
        state => 'unconfirmed',
        quantity => 1,
        new_bins => 1,
        action => 1,
        bin_type => 1,
        payment_method => 'credit_card',
        new_quantity => '',
        new_bin_type => '',
        ref_type => 'scp',
        @_
    );
    $report->discard_changes;
    is $report->category, 'Garden Subscription', 'correct category on report';
    is $report->title, "Garden Subscription - $params{type}", 'correct title on report';
    is $report->get_extra_field_value('payment_method'), $params{payment_method}, 'correct payment method on report';
    is $report->get_extra_field_value('Paid_Collection_Container_Quantity'), $params{quantity}, 'correct bin count';
    is $report->get_extra_field_value('Paid_Collection_Container_Type'), $params{bin_type}, 'correct bin type';
    is $report->get_extra_field_value('Container_Quantity'), $params{new_quantity}, 'correct bin count';
    is $report->get_extra_field_value('Container_Type'), $params{new_bin_type}, 'correct bin type';
    is $report->state, $params{state}, 'report state correct';
    if ($params{state} eq 'unconfirmed') {
        if ($params{ref_type} eq 'apn') {
            is $report->get_extra_metadata('apnReference'), '4ab5f886-de7d-4f5b-bbd8-42151a5deb82', 'correct scp reference on report';
        } else {
            is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
        }
    }
}

sub check_extra_data_post_confirm {
    my $report = shift;
    $report->discard_changes;
    is $report->state, 'confirmed', 'report confirmed';
    is $report->get_extra_field_value('LastPayMethod'), 2, 'correct echo payment method field';
    is $report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
    is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
}

done_testing;
