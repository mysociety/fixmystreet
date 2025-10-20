use Test::MockModule;
use Test::MockObject;
use Test::MockTime qw(:all);
use FixMyStreet::Script::Reports;
use FixMyStreet::TestMech;
use JSON::MaybeXS;
use List::MoreUtils qw(firstidx);
use t::Mock::Bexley;

FixMyStreet::App->log->disable('info', 'error');
END { FixMyStreet::App->log->enable('info', 'error'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2494, 'Bexley', { cobrand => 'bexley' });
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
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Garden Subscription', email => 'garden@example.com'},
    { code => 'current_containers', required => 1, automated => 'hidden_field' },
    { code => 'new_containers', required => 1, automated => 'hidden_field' },
    { code => 'total_containers', required => 1, automated => 'hidden_field' },
    { code => 'customer_external_ref', required => 1, automated => 'hidden_field' },
    { code => 'type', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'pro_rata', required => 1, automated => 'hidden_field' },
    { code => 'renew_as_new_subscription', required => 1, automated => 'hidden_field' },
);
create_contact(
    { category => 'Cancel Garden Subscription', email => 'garden_cancel@example.com' },
    { code => 'customer_external_ref', required => 1, automated => 'hidden_field' },
    { code => 'due_date', required => 1, automated => 'hidden_field' },
    { code => 'reason', required => 1, automated => 'hidden_field' },
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'server' },
);

my $pc180 = {
    SiteServiceID          => 1,
    ServiceItemDescription => 'Non-recyclable waste',
    ServiceItemName => 'PC-180',
    ServiceName          => 'Blue Wheelie Bin',
    NextCollectionDate   => '2024-02-07T00:00:00',
    SiteServiceValidFrom => '2000-01-01T00:00:00',
    SiteServiceValidTo   => '0001-01-01T00:00:00',
    RoundSchedule => 'RND-1 Mon',
};

use t::Mock::AccessPaySuiteBankChecker;
my $bankchecker = t::Mock::AccessPaySuiteBankChecker->new;
LWP::Protocol::PSGI->register($bankchecker->to_psgi_app, host => 'bank.check.example.org');

my $ggw_first_bin_discount = 500;
my $ggw_cost_first = 7500;
my $ggw_cost_first_human = sprintf('%.2f', $ggw_cost_first/100);
my $ggw_cost = 5500;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        waste => { bexley => 1 },
        whitespace => { bexley => {
            url => 'https://example.net/',
        } },
        agile => { bexley => { url => 'test' } },
        payment_gateway => { bexley => {
            ggw_first_bin_discount => $ggw_first_bin_discount,
            ggw_cost_first => $ggw_cost_first,
            ggw_cost => $ggw_cost,
            pro_rata_minimum => 0,
            pro_rata_weekly => 106,
            cc_url => 'http://example.org/cc_submit',
            scpID => 1234,
            hmac_id => 1234,
            hmac => 1234,
            paye_siteID => 1234,
            paye_hmac_id => 1234,
            paye_hmac => 1234,
            dd_schedule_id => 123,
            validator_url => "http://bank.check.example.org/",
            validator_client => "bexley",
            validator_apikey => "mycoolapikey",
        } },
    },
}, sub {
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

    subtest 'check subscription link present' => sub {
        $mech->get_ok('/waste/10001');
        $mech->content_contains('Subscribe to garden waste collection service', 'Subscribe link present if expired');
    };

    subtest 'check Agile API error handling' => sub {
        # Test that various API error responses show the same error handling behavior
        my %error_codes = (
            '503' => 'Service Unavailable',
            '404' => 'Not Found',
            '400' => 'Bad Request'
        );

        foreach my $error_code (keys %error_codes) {
            subtest "Error code $error_code" => sub {
                $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                    error => $error_code,
                    error_message => $error_codes{$error_code}
                } } );

                $mech->get_ok('/waste/10001');
                $mech->content_lacks('Sign up for a garden waste collection', "Sign-up button not shown for $error_code");
                $mech->content_lacks('Subscribe to garden waste collection service', "Subscribe link not shown for $error_code");
                $mech->content_contains("We're currently unable to check your garden waste subscription status", "API error message shown for $error_code");
                $mech->content_contains('Please try again later. If the problem persists, contact us directly', "API error help text shown for $error_code");
            };
        }

        default_mocks();
    };

    subtest 'check new sub bin limits' => sub {
        $mech->get_ok('/waste/10001/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes' } });
        $mech->content_contains('Please specify how many bins you already have');
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        my $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        is $mech->value('current_bins'), 0, "current bins is set to 0";

        $mech->get_ok('/waste/10001/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 1 } });
        $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        $mech->content_like(qr#Total to pay now: £<span[^>]*>$ggw_cost_first_human#, "initial cost set correctly");
        is $mech->value('current_bins'), 1, "current bins is set to 1";
    };

    subtest 'check new sub credit card payment' => sub {
        my $test = {
            month => '01',
            pounds_cost => sprintf("%.2f", ($ggw_cost_first + $ggw_cost)/100),
            pence_cost => $ggw_cost_first + $ggw_cost,
        };
        set_fixed_time("2021-$test->{month}-09T17:00:00Z");
        $mech->get_ok('/waste/10001/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 2,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£' . $test->{pounds_cost});
        $mech->content_contains('2 bins');
        $mech->submit_form_ok({ with_fields => { goto => 'details' } });
        $mech->content_contains('<span id="cost_pa">' . $test->{pounds_cost});
        $mech->content_contains('<span id="cost_now">' . $test->{pounds_cost});
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 2,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('Continue to payment', 'Waste features text_for_waste_payment not used for non-staff payment');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, $test->{pence_cost}, 'correct amount used';
        check_extra_data_pre_confirm(
            $new_report,
            current_bins => 0,
            new_bins     => 2,
            bins_wanted  => 2,
        );

        $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");

        check_extra_data_post_confirm($new_report);

        $mech->content_like(qr#/waste/10001">Show upcoming#, "contains link to bin page");

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $email_body = $mech->get_text_body_from_email($emails[1]);
        like $email_body, qr/Number of bin subscriptions: 2/;
        like $email_body, qr/Bins to be delivered: 2/;
        like $email_body, qr/Total:.*?$test->{pounds_cost}/;
        $mech->clear_emails_ok;
    };

    set_fixed_time('2023-01-09T17:00:00Z'); # Set a date when garden service full price for most tests

    subtest 'check new sub credit card payment with no bins required' => sub {
        $mech->get_ok('/waste/10001/garden');
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
        $mech->content_contains('£' . $ggw_cost_first_human);
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, $ggw_cost_first, 'correct amount used';
        check_extra_data_pre_confirm(
            $new_report,
            current_bins => 1,
            new_bins     => 0,
            bins_wanted  => 1,
        );

        $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $email_body = $mech->get_text_body_from_email($emails[1]);
        like $email_body, qr/Number of bin subscriptions: 1/;
        unlike $email_body, qr/Bins to be delivered/;
        like $email_body, qr/Total:.*?$ggw_cost_first_human/;
    };

    subtest 'check new sub credit card payment with one less bin required' => sub {
        $mech->get_ok('/waste/10001/garden');
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
        $mech->content_contains('£' . $ggw_cost_first_human);
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, $ggw_cost_first, 'correct amount used';
        check_extra_data_pre_confirm(
            $new_report,
            current_bins => 2,
            new_bins     => -1,
            bins_wanted  => 1,
        );

        $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $email_body = $mech->get_text_body_from_email($emails[1]);
        like $email_body, qr/Number of bin subscriptions: 1/;
        like $email_body, qr/Bins to be removed: 1/;
        like $email_body, qr/Total:.*?$ggw_cost_first_human/;
    };

    subtest 'modify garden subscription' => sub {
        set_fixed_time('2024-02-01T00:00:00');
        $mech->delete_problems_for_body($body->id);

        my $uprn = 10001;
        my $contract_id = 'CONTRACT_123';

        my ($new_sub_report) = $mech->create_problems_for_body(
            1,
            $body->id,
            'Garden Subscription - New',
            {   category    => 'Garden Subscription',
                external_id => "Agile-$contract_id",
                user => $user,
            },
        );
        $new_sub_report->set_extra_fields(
            { name => 'uprn', value => $uprn } );
        $new_sub_report->update;
        FixMyStreet::Script::Reports::send();

        $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
            Customers => [
                {
                    CustomerExternalReference => 'CUSTOMER_123',
                    Firstname => '  Verity  ',
                    Surname => '  Wright  ',
                    Email => 'verity@wright.com',
                    Mobile => '+4407222222222',
                    CustomertStatus => 'ACTIVATED',
                    ServiceContracts => [
                        {
                            EndDate => '01/02/2025 12:00',
                            Reference => $contract_id,
                            WasteContainerQuantity => 2,
                            ServiceContractStatus => 'ACTIVE',
                            UPRN => '10001',
                            Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => '' } ]
                        },
                    ],
                },
            ],
        } } );

        $bexley_mocks{whitespace}->mock(
            'GetSiteCollections',
            sub {
                [   {   SiteServiceID          => 1,
                        ServiceItemDescription => 'Garden waste',
                        ServiceItemName => 'GA-140',  # Garden 140 ltr Bin
                        ServiceName          => 'Brown Wheelie Bin',
                        NextCollectionDate   => '2024-02-07T00:00:00',
                        SiteServiceValidFrom => '2024-01-01T00:00:00',
                        SiteServiceValidTo   => '0001-01-01T00:00:00',

                        RoundSchedule => 'RND-1 Mon',
                    },
                    $pc180,
                ];
            }
        );

        subtest 'nobody logged in' => sub {
            $mech->log_out_ok;

            $mech->get_ok("/waste/$uprn");
            like $mech->content, qr/Change your brown wheelie bin subscription/, 'modify link present';

            $mech->get_ok("/waste/$uprn/garden_modify");
            like $mech->text, qr/Sign in or create an account/, 'modify link goes to login page';
        };

        subtest 'other user logged in' => sub {
            my $other_user = $mech->create_user_ok('other@example.net', name => 'Other User');

            $mech->log_in_ok( $other_user->email );

            $mech->get_ok("/waste/$uprn");
            like $mech->content, qr/Change your brown wheelie bin subscription/, 'modify link present';

            $mech->get_ok("/waste/$uprn/garden_modify");
            $mech->submit_form_ok(
                {   with_fields => {
                        task => 'modify',
                    },
                }, 'initial option page',
            );
            $mech->submit_form_ok(
                {   with_fields => {
                        has_reference => 'Yes',
                        customer_reference => 'CUSTOMER_BAD',
                    },
                },
            );
            like $mech->text, qr/Incorrect customer reference/,
                'error message shown on next page if bad reference';

            subtest 'goes to verification failed page if wrong name provided' => sub {
                $mech->submit_form_ok(
                    {   with_fields => {
                            verifications_first_name => 'A',
                            verifications_last_name  => 'Name',
                        },
                    },
                );
                like $mech->text, qr/Verification failed/;

                subtest 'can go back to customer reference input' => sub {
                    $mech->submit_form_ok(
                        { with_fields => { goto => 'customer_reference' } } );
                };
            };

            subtest 'can continue to modify if correct name provided' => sub {
                $mech->submit_form_ok(
                    {   with_fields => {
                            has_reference => 'Yes',
                            customer_reference => 'CUSTOMER_BAD',
                        },
                    },
                );
                $mech->submit_form_ok(
                    {   with_fields => {
                            verifications_first_name => ' Verity ',
                            verifications_last_name  => ' Wright ',
                        },
                    },
                );
                like $mech->text, qr/Change your garden waste subscription/;
            };
        };

        subtest 'staff logged in' => sub {
            $mech->log_in_ok( $staff_user->email );

            $mech->get_ok("/waste/$uprn");
            like $mech->content, qr/Change your brown wheelie bin subscription/, 'modify link present';

            $mech->get_ok("/waste/$uprn/garden_modify");
            $mech->submit_form_ok(
                {   with_fields => {
                        task => 'modify',
                    },
                }, 'initial option page',
            );
            $mech->submit_form_ok(
                {   with_fields => {
                        has_reference => 'Yes',
                        customer_reference => 'CUSTOMER_BAD',
                    },
                },
            );
            like $mech->text, qr/First name/,
                'Bad reference takes user to name input';
            $mech->back;
            $mech->submit_form_ok(
                {   with_fields => {
                        has_reference => 'Yes',
                        customer_reference => 'customer_123',
                    },
                },
            );
            like $mech->text, qr/Change your garden waste subscription/, 'modification permitted';

            $mech->submit_form_ok(
                {   with_fields => {
                        bins_wanted => 4,
                    },
                }
            );
            like $mech->text, qr/Your nameVerity Wright/,
                'correct name in summary (from Agile data)';
            my $email = $user->email;
            like $mech->text, qr/verity\@wright.com/,
                'correct email in summary (from Agile data)';
            like $mech->text, qr/4407222222222/,
                'correct phone in summary (from Agile data)';
        };

        subtest 'original user logged in' => sub {
            $mech->log_in_ok( $user->email );

            subtest 'original payment method of credit card' => sub {
                $new_sub_report->update_extra_field(
                    { name => 'payment_method', value => 'credit_card' } );
                $new_sub_report->update;

                subtest 'cannot modify during last 42 days of subscription' => sub {
                    set_fixed_time('2024-12-21T12:00:00');

                    $mech->get_ok("/waste/$uprn");
                    unlike $mech->content,
                        qr/Change your brown wheelie bin subscription/,
                        'No modification link';
                    like $mech->content,
                        qr/Renew your brown wheelie bin subscription/,
                        'Renewal link instead';

                    $mech->get_ok("/waste/$uprn/garden_modify");
                    like $mech->text, qr/Your bin days/,
                        'garden_modify redirects to bin days';
                };

                set_fixed_time('2024-02-01T00:00:00');
                $mech->get_ok("/waste/$uprn");
                like $mech->content, qr/Change your brown wheelie bin subscription/;

                $mech->get_ok("/waste/$uprn/garden_modify");
                $mech->submit_form_ok(
                    {   with_fields => {
                            task => 'modify',
                        },
                    }, 'initial option page',
                );
                $mech->submit_form_ok(
                    {   with_fields => {
                            has_reference => 'No',
                        },
                    },
                );
                $mech->submit_form_ok(
                    {   with_fields => {
                            verifications_first_name => 'Verity',
                            verifications_last_name => 'Wright',
                        },
                    }
                );
                like $mech->text, qr/Change your garden waste subscription/, 'modification permitted';
                like $mech->content, qr/current_bins.*value="2"/s, 'correct number of current bins prefilled';

                subtest 'add bins' => sub {
                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 2,
                            },
                        }
                    );
                    like $mech->text,
                        qr/You need to change the number of bins/,
                        'error message if bin count not changed';

                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 4,
                            },
                        }
                    );

                    like $mech->text, qr/Garden waste collection4 bins/, 'correct bin total in summary';
                    like $mech->text, qr/Total.240\.00/, 'correct payment total in summary';
                    like $mech->text, qr/Total to pay today.108\.12/, 'correct today-payment in summary';
                    like $mech->text, qr/Your nameVerity Wright/, 'correct name in summary';
                    my $email = $user->email;
                    like $mech->text, qr/$email/, 'User email in summary';

                    $mech->waste_submit_check({ with_fields => { tandc => 1 } });

                    my ( $token, $modify_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

                    is $sent_params->{items}[0]{amount}, 10812, 'correct amount used';
                    check_extra_data_pre_confirm(
                        $modify_report,
                        type         => 'Amend',
                        current_bins => 2,
                        new_bins     => 2,
                        bins_wanted  => 4,
                        customer_external_ref => 'CUSTOMER_123',
                    );
                    is $modify_report->get_extra_field_value('type'), 'amend',
                        'correct report type';
                    is $modify_report->get_extra_field_value(
                        'total_containers'), 4,
                        'correct total_containers';

                    $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
                    check_extra_data_post_confirm($modify_report);

                    $mech->clear_emails_ok;
                    FixMyStreet::Script::Reports::send();
                    my @emails = $mech->get_email;
                    my $email_body = $mech->get_text_body_from_email($emails[1]);
                    like $email_body,
                        qr/You have amended your garden waste collection service/;
                    like $email_body, qr/Number of bin subscriptions: 4/;
                    like $email_body, qr/Bins to be delivered: 2/;
                    like $email_body, qr/Total:.*?108\.12/;
                };

                subtest 'remove bins' => sub {
                    $mech->get_ok("/waste/$uprn/garden_modify");
                    $mech->submit_form_ok(
                        {   with_fields => {
                                task => 'modify',
                            },
                        }, 'initial option page',
                    );
                    $mech->submit_form_ok(
                        {   with_fields => {
                                has_reference => 'Yes',
                                customer_reference => 'CUSTOMER_123',
                            },
                        },
                    );
                    like $mech->content, qr/current_bins.*value="2"/s, 'correct number of current bins prefilled'; # No change in Agile
                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 1,
                            },
                        }
                    );

                    like $mech->text, qr/Garden waste collection1 bin/, 'correct bin total in summary';
                    like $mech->text, qr/Total.75\.00/, 'correct payment total in summary';
                    like $mech->text, qr/Total to pay today.0\.00/, 'correct today-payment in summary';
                    like $mech->text, qr/Your nameVerity Wright/, 'correct name in summary';
                    my $email = $user->email;
                    like $mech->text, qr/$email/, 'correct email in summary';

                    # No payment/redirect
                    $mech->submit_form_ok(
                        { with_fields => { tandc => 1 } } );

                    my $modify_report = FixMyStreet::DB->resultset('Problem')
                        ->order_by('-id')->first;

                    check_extra_data_pre_confirm(
                        $modify_report,
                        type         => 'Amend',
                        current_bins => 2,
                        new_bins     => -1,
                        bins_wanted  => 1,
                        state => 'confirmed',
                        customer_external_ref => 'CUSTOMER_123',
                    );
                    is $modify_report->get_extra_field_value('type'), 'amend',
                        'correct report type';
                    is $modify_report->get_extra_field_value(
                        'total_containers'), 1,
                        'correct total_containers';

                    $mech->clear_emails_ok;
                    FixMyStreet::Script::Reports::send();
                    my @emails = $mech->get_email;
                    my $email_body = $mech->get_text_body_from_email($emails[1]);
                    like $email_body,
                        qr/You have amended your garden waste collection service/;
                    like $email_body, qr/Number of bin subscriptions: 1/;
                    like $email_body, qr/Bins to be removed: 1/;
                    unlike $email_body, qr/Total:/;

                };

            };

            subtest 'original payment method of direct debit' => sub {
                $mech->delete_problems_for_body($body->id);
                my $dd_customer_id = 'DD_CUSTOMER_123';
                my $dd_contract_id = 'DD_CONTRACT_123';

                my $access_mock
                    = Test::MockModule->new('Integrations::AccessPaySuite');
                $access_mock->mock(
                    get_contracts => sub { [ { Status => 'Active' } ] },
                );
                $access_mock->mock(
                    create_contract => sub {
                        {   Id             => 'CONTRACT_123',
                            DirectDebitRef => 'APIRTM-DEFGHIJ1KL'
                        };
                    }
                );
                $access_mock->mock(
                    create_payment => sub { {} } # Empty hash implies success
                );

                my $amend_plan_args;
                $access_mock->mock(
                    amend_plan => sub {
                        my ( $self, $args ) = @_;
                        $amend_plan_args = $args;
                        return 1;
                    }
                );

                my ($orig_dd_sub_report) = $mech->create_problems_for_body(
                    1,
                    $body->id,
                    'Title which is overwritten below because we don\'t want the junk that is appended by default',
                    {
                        category    => 'Garden Subscription',
                        title => 'Garden Subscription - New',
                        external_id => "Agile-$dd_contract_id",
                        user => $user,
                    },
                );
                $orig_dd_sub_report->set_extra_fields(
                    { name => 'payment_method', value => 'direct_debit' },
                    { name => 'uprn', value => $uprn },
                );
                $orig_dd_sub_report->set_extra_metadata(
                    direct_debit_customer_id => $dd_customer_id,
                    direct_debit_contract_id => $dd_contract_id,
                );
                $orig_dd_sub_report->update;
                FixMyStreet::Script::Reports::send();

                $mech->log_in_ok( $user->email );
                $mech->get_ok("/waste/$uprn/garden_modify");
                $mech->submit_form_ok(
                    {   with_fields => {
                            task => 'modify',
                        },
                    }, 'initial option page',
                );
                $mech->submit_form_ok(
                    {   with_fields => {
                            has_reference => 'Yes',
                            customer_reference => 'CUSTOMER_123',
                        },
                    },
                );

                like $mech->content, qr/current_bins.*value="2"/s, 'correct number of current bins prefilled';
                my $old_annual_cost_pence
                    = $ggw_cost_first - $ggw_first_bin_discount + $ggw_cost;
                my $old_annual_cost_human
                    = sprintf( '%.2f', $old_annual_cost_pence / 100 );
                like $mech->text,
                    qr/Total per year.*£$old_annual_cost_human/,
                    'correct original cost displayed';

                $mech->submit_form_ok(
                    {   with_fields => {
                            bins_wanted => 3,
                        },
                    },
                    "Modify"
                );

                my $new_annual_cost_pence = $old_annual_cost_pence + $ggw_cost;
                my $new_annual_cost_human = sprintf('%.2f', $new_annual_cost_pence / 100);

                like $mech->text, qr/Garden waste collection3 bins/,
                    'correct bin total in summary';
                like $mech->text, qr/Total£$new_annual_cost_human/,
                    'correct new annual payment total in summary';
                like $mech->text, qr/Total to pay today.54\.06/,
                    'correct today-payment in summary';
                like $mech->text, qr/Your nameVerity Wright/,
                    'correct name in summary';
                my $email = $user->email;
                like $mech->text, qr/$email/, 'correct email in summary';

                $mech->submit_form_ok( { with_fields => { tandc => 1 } }, "Confirm" );

                ok $amend_plan_args, 'Integrations::AccessPaySuite->amend_plan was called';
                isa_ok $amend_plan_args->{orig_sub}, 'FixMyStreet::DB::Result::Problem', 'amend_plan received report object for original sub';
                is $amend_plan_args->{orig_sub}->id, $orig_dd_sub_report->id, 'amend_plan received correct original report object';
                is $amend_plan_args->{amount}, $new_annual_cost_human, 'amend_plan called with correct new annual amount';

                my $modify_report = FixMyStreet::DB->resultset('Problem')
                    ->search({ title => 'Garden Subscription - Amend' })
                    ->order_by('-id')->first;

                ok $modify_report, "Found the amend report";
                is $modify_report->category, 'Garden Subscription', 'Amend report: correct category';
                is $modify_report->title, "Garden Subscription - Amend", 'Amend report: correct title';
                is $modify_report->get_extra_field_value('payment_method'), 'direct_debit', 'Amend report: correct payment method';
                is $modify_report->get_extra_field_value('current_containers'), 2, 'Amend report: correct current_containers';
                is $modify_report->get_extra_field_value('new_containers'), 1, 'Amend report: correct new_containers';
                is $modify_report->get_extra_field_value('total_containers'), 3, 'Amend report: correct total_containers';
                is $modify_report->get_extra_field_value('type'), 'amend', 'Amend report: correct type';
                is $modify_report->get_extra_field_value('customer_external_ref'), 'CUSTOMER_123', 'Amend report: correct customer_external_ref';
                is $modify_report->state, 'confirmed',
                    'Amend report: state correct (confirmed for DD amend)';

                $access_mock->unmock_all;
            };

        };
    };

    subtest 'mid-year pro-rata calculation' => sub {
        set_fixed_time('2024-08-01T00:00:00'); # 6 months after start
        $mech->delete_problems_for_body($body->id);

        my $uprn = 10001;
        my $contract_id = 'CONTRACT_456';

        my ($new_sub_report) = $mech->create_problems_for_body(
            1,
            $body->id,
            'Garden Subscription - New',
            {   category    => 'Garden Subscription',
                external_id => "Agile-$contract_id",
                user => $user,
            },
        );
        $new_sub_report->set_extra_fields(
            { name => 'uprn', value => $uprn } );
        $new_sub_report->update;
        FixMyStreet::Script::Reports::send();

        $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
            Customers => [
                {
                    CustomerExternalReference => 'CUSTOMER_456',
                    Firstname => 'Test',
                    Surname => 'User',
                    Email => 'test@example.com',
                    Mobile => '+4407111111111',
                    CustomertStatus => 'ACTIVATED',
                    ServiceContracts => [
                        {
                            EndDate => '01/02/2025 12:00', # 6 months remaining
                            Reference => $contract_id,
                            WasteContainerQuantity => 2,
                            ServiceContractStatus => 'ACTIVE',
                            UPRN => '10001',
                            Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => '' } ]
                        },
                    ],
                },
            ],
        } } );

        $bexley_mocks{whitespace}->mock(
            'GetSiteCollections',
            sub {
                [   {   SiteServiceID          => 1,
                        ServiceItemDescription => 'Garden waste',
                        ServiceItemName => 'GA-140',
                        ServiceName          => 'Brown Wheelie Bin',
                        NextCollectionDate   => '2024-08-07T00:00:00',
                        SiteServiceValidFrom => '2024-02-01T00:00:00',
                        SiteServiceValidTo   => '0001-01-01T00:00:00',
                        RoundSchedule => 'RND-1 Mon',
                    }
                ];
            }
        );

        $mech->log_in_ok( $user->email );

        # Expected pro-rata cost per bin: 25 weeks * 106 pence per week = 2650 pence
        my $cost_per_bin = 25 * 106;

        subtest 'credit card payment' => sub {
            for my $test ({ bins => 1, total => 3 }, { bins => 2, total => 4 }) {
                subtest "adding $test->{bins} bin(s)" => sub {
                    $mech->get_ok("/waste/$uprn/garden_modify");
                    $mech->submit_form_ok({ with_fields => { task => 'modify' } });
                    $mech->submit_form_ok({ with_fields => { has_reference => 'No' } });
                    $mech->submit_form_ok({
                        with_fields => {
                            verifications_first_name => 'Test',
                            verifications_last_name => 'User',
                        }
                    });

                    $mech->submit_form_ok({ with_fields => { bins_wanted => $test->{total} } });

                    my $expected = $cost_per_bin * $test->{bins};
                    my $expected_human = sprintf('%.2f', $expected / 100);

                    like $mech->text, qr/Garden waste collection$test->{total} bins/, 'correct bin total';
                    like $mech->text, qr/Total to pay today.$expected_human/, 'correct pro-rata payment';

                    $mech->waste_submit_check({ with_fields => { tandc => 1 } });
                    is $sent_params->{items}[0]{amount}, $expected, 'correct payment amount';
                };
            }
        };

        subtest 'direct debit payment' => sub {
            $mech->delete_problems_for_body($body->id);

            my $dd_customer_id = 'DD_CUSTOMER_456';
            my $dd_contract_id = 'DD_CONTRACT_456';

            my ($dd_sub_report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Garden Subscription - New',
                {
                    category    => 'Garden Subscription',
                    title => 'Garden Subscription - New',
                    external_id => "Agile-$dd_contract_id",
                    user => $user,
                },
            );
            $dd_sub_report->set_extra_fields(
                { name => 'payment_method', value => 'direct_debit' },
                { name => 'uprn', value => $uprn },
            );
            $dd_sub_report->set_extra_metadata(
                direct_debit_customer_id => $dd_customer_id,
                direct_debit_contract_id => $dd_contract_id,
                payerReference => 'DD_PAYER_REF_456',
            );
            $dd_sub_report->update;
            FixMyStreet::Script::Reports::send();

            my $access_mock = Test::MockModule->new('Integrations::AccessPaySuite');
            $access_mock->mock(
                get_contracts => sub { [ { Status => 'Active' } ] },
            );

            my ($one_off_args, $amend_plan_args);
            $access_mock->mock(
                one_off_payment => sub {
                    my ( $self, $args ) = @_;
                    $one_off_args = $args;
                    return 'ONE_OFF_REF_123';
                }
            );
            $access_mock->mock(
                amend_plan => sub {
                    my ( $self, $args ) = @_;
                    $amend_plan_args = $args;
                    return 1;
                }
            );

            for my $test ({ bins => 1, total => 3 }, { bins => 2, total => 4 }) {
                subtest "adding $test->{bins} bin(s)" => sub {
                    $mech->get_ok("/waste/$uprn/garden_modify");
                    $mech->submit_form_ok({ with_fields => { task => 'modify' } });
                    $mech->submit_form_ok({ with_fields => { has_reference => 'No' } });
                    $mech->submit_form_ok({
                        with_fields => {
                            verifications_first_name => 'Test',
                            verifications_last_name => 'User',
                        }
                    });

                    $mech->submit_form_ok({ with_fields => { bins_wanted => $test->{total} } });

                    my $expected_pro_rata = $cost_per_bin * $test->{bins};
                    my $expected_pro_rata_human = sprintf('%.2f', $expected_pro_rata / 100);

                    like $mech->text, qr/Garden waste collection$test->{total} bins/, 'correct bin total';
                    like $mech->text, qr/Total to pay today.$expected_pro_rata_human/, 'correct pro-rata payment';

                    $mech->submit_form_ok({ with_fields => { tandc => 1 } });

                    ok $one_off_args, 'one_off_payment was called';
                    is $one_off_args->{payer_reference}, 'DD_PAYER_REF_456', 'correct payer reference';
                    is $one_off_args->{amount}, $expected_pro_rata_human, 'correct ad-hoc payment amount';
                    isa_ok $one_off_args->{orig_sub}, 'FixMyStreet::DB::Result::Problem', 'one_off_payment received original sub';
                    is $one_off_args->{orig_sub}->id, $dd_sub_report->id, 'one_off_payment received correct original sub';

                    ok $amend_plan_args, 'amend_plan was called';
                    is $amend_plan_args->{payer_reference}, 'DD_PAYER_REF_456', 'amend_plan: correct payer reference';

                    my $modify_report = FixMyStreet::DB->resultset('Problem')
                        ->search({ title => 'Garden Subscription - Amend' })
                        ->order_by('-id')->first;

                    ok $modify_report, "Found the amend report";
                    is $modify_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method';
                    is $modify_report->get_extra_field_value('pro_rata'), $expected_pro_rata, 'correct pro_rata field';
                    is $modify_report->state, 'confirmed', 'report confirmed';

                    undef $one_off_args;
                    undef $amend_plan_args;
                };
            }

            $access_mock->unmock_all;
        };
    };

    subtest 'renew garden subscription' => sub {
        set_fixed_time('2024-02-01T00:00:00');
        $mech->delete_problems_for_body($body->id);
        default_mocks();

        my $uprn = 10001;
        my $contract_id = 'CONTRACT_123';

        my ($new_sub_report) = $mech->create_problems_for_body(
            1,
            $body->id,
            'Garden Subscription - New',
            {   category    => 'Garden Subscription',
                external_id => "Agile-$contract_id",
            },
        );
        $new_sub_report->set_extra_fields(
            { name => 'uprn', value => $uprn } );
        $new_sub_report->update;
        FixMyStreet::Script::Reports::send();

        $mech->log_in_ok( $user->email );

        subtest 'with active contract elsewhere' => sub {
            $bexley_mocks{whitespace}->mock('GetSiteCollections', sub {
                [ {
                    SiteServiceID          => 1,
                    ServiceItemDescription => 'Non-recyclable waste',
                    ServiceItemName => 'PC-180',
                    ServiceName          => 'Blue Wheelie Bin',
                    NextCollectionDate   => '2024-02-07T00:00:00',
                    SiteServiceValidFrom => '2000-01-01T00:00:00',
                    SiteServiceValidTo   => '0001-01-01T00:00:00',
                    RoundSchedule => 'RND-1 Mon',
                } ];
            });
            $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                Customers => [
                    {
                        CustomerExternalReference => 'CUSTOMER_123',
                        CustomertStatus => 'ACTIVATED',
                        ServiceContracts => [
                            {
                                # 42 days away
                                EndDate => '14/03/2024 12:00',
                                Reference => $contract_id,
                                WasteContainerQuantity => 2,
                                ServiceContractStatus => 'ACTIVE',
                                UPRN => '10002',
                                Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => '' } ]
                            },
                        ],
                    },
                ],
            } } );

            $mech->get_ok("/waste/$uprn");
            like $mech->content, qr/You do not have a Garden waste collection/;
        };

        subtest 'with no garden container in Whitespace' => sub {
            $bexley_mocks{whitespace}->mock( 'GetSiteCollections', sub { [] } );
            $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                Customers => [
                    {
                        CustomerExternalReference => 'CUSTOMER_123',
                        CustomertStatus => 'ACTIVATED',
                        ServiceContracts => [
                            {
                                # 42 days away
                                EndDate => '14/03/2024 12:00',
                                Reference => $contract_id,
                                WasteContainerQuantity => 2,
                                ServiceContractStatus => 'ACTIVE',
                                UPRN => '10001',
                                Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                            },
                        ],
                    },
                ],
            } } );

            $mech->get_ok("/waste/$uprn");
            like $mech->content, qr/Renew subscription today/,
                '"Renew today" notification box shown';
            like $mech->content, qr/14 March 2024, soon due for renewal/,
                '"Due soon" message shown';
            like $mech->content,
                qr/Renew your brown wheelie bin subscription/,
                'Renewal link available';
            like $mech->text, qr/Frequency.*Pending/,
                'Details pending because no Whitespace data';
        };

        subtest 'with garden container in Whitespace' => sub {
            $bexley_mocks{whitespace}->mock(
                'GetSiteCollections',
                sub {
                    [   {   SiteServiceID          => 1,
                            ServiceItemDescription => 'Garden waste',
                            ServiceItemName => 'GA-140',  # Garden 140 ltr Bin
                            ServiceName          => 'Brown Wheelie Bin',
                            NextCollectionDate   => '2024-02-07T00:00:00',
                            SiteServiceValidFrom => '2024-01-01T00:00:00',
                            SiteServiceValidTo   => '0001-01-01T00:00:00',

                            RoundSchedule => 'RND-1 Mon',
                        }
                    ];
                }
            );

            subtest 'already renewed' => sub {
                $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                    Customers => [
                        {
                            CustomerExternalReference => 'CUSTOMER_123',
                            CustomertStatus => 'ACTIVATED',
                            ServiceContracts => [
                                {
                                    # 42 days away
                                    EndDate => '14/03/2024 12:00',
                                    Reference => $contract_id,
                                    WasteContainerQuantity => 2,
                                    ServiceContractStatus => 'RENEWALDUE',
                                    UPRN => '10001',
                                    Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                },
                            ],
                        },
                    ],
                } } );

                $mech->get_ok("/waste/$uprn");
                like $mech->content,
                    qr/Change your brown wheelie bin subscription/,
                    'can amend subscription';
                unlike $mech->content, qr/Renew subscription today/,
                    '"Renew today" notification box not shown';
                unlike $mech->content, qr/14 March 2024, soon due for renewal/,
                    '"Due soon" message not shown';
                unlike $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'Renewal link not available';
            };

            subtest 'within renewal window' => sub {
                $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                    Customers => [
                        {
                            CustomerExternalReference => 'CUSTOMER_123',
                            Firstname => 'Verity',
                            Surname => 'Wright',
                            CustomertStatus => 'ACTIVATED',
                            ServiceContracts => [
                                {
                                    # 42 days away
                                    EndDate => '14/03/2024 12:00',
                                    Reference => $contract_id,
                                    WasteContainerQuantity => 2,
                                    ServiceContractStatus => 'ACTIVE',
                                    UPRN => '10001',
                                    Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                },
                            ],
                        },
                    ],
                } } );

                $mech->get_ok("/waste/$uprn");
                unlike $mech->content,
                    qr/Change your brown wheelie bin subscription/,
                    'cannot amend subscription';
                like $mech->content, qr/Renew subscription today/,
                    '"Renew today" notification box shown';
                like $mech->content, qr/14 March 2024, soon due for renewal/,
                    '"Due soon" message shown';
                like $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'Renewal link available';
                like $mech->text, qr/Frequency.*Wednesday 7 February 2024/,
                    'Details are not pending because we have Whitespace data';

                subtest 'verification failed' => sub {
                    $mech->get_ok("/waste/$uprn/garden_renew");

                    $mech->submit_form_ok(
                        {   with_fields => {
                                has_reference => 'Yes',
                                customer_reference => 'CUSTOMER_BAD',
                            },
                        },
                    );
                    like $mech->text, qr/Incorrect customer reference/,
                        'error message shown on next page if bad reference';
                    $mech->submit_form_ok(
                        {   with_fields => {
                                verifications_first_name => 'Ferrety',
                                verifications_last_name => 'Wright',
                                email => 'ferrety@wright.com',
                            },
                        },
                    );

                    like $mech->text,
                        qr/Renew your garden waste subscription/,
                        'Can still renew';
                    like $mech->content, qr/name="current_bins.*value="2"/s,
                        'Current bins pre-populated';
                    like $mech->content, qr/name="bins_wanted.*value="2"/s,
                        'Wanted bins pre-populated';

                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 2,
                                payment_method => 'credit_card',
                            },
                        }
                    );
                    $mech->waste_submit_check(
                        { with_fields => { tandc => 1 } } );

                    my ( $token, $renew_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

                    # Should be blank customer_external_reference
                    check_extra_data_pre_confirm(
                        $renew_report,
                        type         => 'New',
                        current_bins => 2,
                        new_bins     => 0,
                        bins_wanted  => 2,
                        customer_external_ref => '',
                        renew_as_new_subscription => 1,
                    );

                    $renew_report->delete;
                };

                $mech->get_ok("/waste/$uprn/garden_renew");
                $mech->submit_form_ok(
                    {   with_fields => {
                            has_reference => 'Yes',
                            customer_reference => '123456',
                        },
                    },
                );
                $mech->submit_form_ok(
                    {   with_fields => {
                            verifications_first_name => 'verity',
                            verifications_last_name => 'WRIGHT',
                            email => 'verity@wright.com',
                            phone => '+4407111111111',
                        },
                    }
                );
                like $mech->content, qr/name="current_bins.*value="2"/s,
                    'Current bins pre-populated';
                like $mech->content, qr/name="bins_wanted.*value="2"/s,
                    'Wanted bins pre-populated';

                subtest 'requesting more bins' => sub {
                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 3,
                                payment_method => 'credit_card',
                            },
                        }
                    );

                    like $mech->text,
                        qr/Please review the information you’ve provided/,
                        'On review page';
                    like $mech->text,
                        qr/Total£185.00/, 'correct cost';
                    $mech->waste_submit_check(
                        { with_fields => { tandc => 1 } } );

                    my ( $token, $renew_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
                    check_extra_data_pre_confirm(
                        $renew_report,
                        type         => 'Renew',
                        current_bins => 2,
                        new_bins     => 1,
                        bins_wanted  => 3,
                        customer_external_ref => 'CUSTOMER_123',
                    );
                    is $renew_report->get_extra_field_value('uprn'), $uprn;
                    is $renew_report->get_extra_field_value('payment'), $ggw_cost_first + 2 * $ggw_cost;
                    is $renew_report->get_extra_field_value('type'), 'renew';

                    $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
                    check_extra_data_post_confirm($renew_report);

                    $mech->clear_emails_ok;
                    FixMyStreet::Script::Reports::send();

                    my @emails = $mech->get_email;
                    my ($to_user) = grep {
                        $mech->get_text_body_from_email($_)
                            =~ /Thank you for renewing your subscription/
                    } @emails;
                    ok $to_user, 'Email sent to user';
                    my $email_body = $mech->get_text_body_from_email($to_user);
                    like $email_body, qr/Number of bin subscriptions: 3/;
                    like $email_body, qr/Bins to be delivered: 1/;
                    unlike $email_body, qr/Bins to be removed/;
                    like $email_body, qr/Total:.*?185.00/;

                    $renew_report->delete;
                };

                subtest 'requesting fewer bins' => sub {
                    $mech->get_ok("/waste/$uprn/garden_renew");

                    $mech->submit_form_ok(
                        {   with_fields => {
                                has_reference => 'Yes',
                                customer_reference => 'CUSTOMER_123',
                            },
                        },
                    );

                    like $mech->content, qr/name="current_bins.*value="2"/s,
                        'Current bins pre-populated';
                    like $mech->content, qr/name="bins_wanted.*value="2"/s,
                        'Wanted bins pre-populated';
                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 1,
                                payment_method => 'credit_card',
                            },
                        }
                    );

                    like $mech->text,
                        qr/Total£$ggw_cost_first_human/, 'correct cost';
                    $mech->waste_submit_check(
                        { with_fields => { tandc => 1 } } );

                    my ( $token, $renew_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
                    check_extra_data_pre_confirm(
                        $renew_report,
                        type         => 'Renew',
                        current_bins => 2,
                        new_bins     => -1,
                        bins_wanted  => 1,
                        customer_external_ref => 'CUSTOMER_123',
                    );
                    is $renew_report->get_extra_field_value('uprn'), $uprn;
                    is $renew_report->get_extra_field_value('payment'), $ggw_cost_first;
                    is $renew_report->get_extra_field_value('type'), 'renew';

                    $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
                    check_extra_data_post_confirm($renew_report);

                    $mech->clear_emails_ok;
                    FixMyStreet::Script::Reports::send();

                    my @emails = $mech->get_email;
                    my ($to_user) = grep {
                        $mech->get_text_body_from_email($_)
                            =~ /Thank you for renewing your subscription/
                    } @emails;
                    ok $to_user, 'Email sent to user';
                    my $email_body = $mech->get_text_body_from_email($to_user);
                    like $email_body, qr/Number of bin subscriptions: 1/;
                    unlike $email_body, qr/Bins to be delivered/;
                    like $email_body, qr/Bins to be removed: 1/;
                    like $email_body, qr/Total:.*?$ggw_cost_first_human/;

                    $renew_report->delete;
                };

            };

            is +FixMyStreet::DB->resultset('Problem')->count, 1,
                'only original subscription in DB';

            subtest 'too early' => sub {
                $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                    Customers => [
                        {
                            CustomerExternalReference => 'CUSTOMER_123',
                            CustomertStatus => 'ACTIVATED',
                            ServiceContracts => [
                                {
                                    # 43 days away
                                    EndDate => '15/03/2024 12:00',
                                    Reference => $contract_id,
                                    WasteContainerQuantity => 2,
                                    ServiceContractStatus => 'ACTIVE',
                                    UPRN => '10001',
                                    Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                },
                            ],
                        },
                    ],
                } } );

                $mech->get_ok("/waste/$uprn");
                like $mech->content,
                    qr/Change your brown wheelie bin subscription/,
                    'can amend subscription';
                like $mech->content, qr/Renewal.*15 March 2024/s,
                    'Renewal date shown';
                unlike $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'Renewal link unavailable';
            };

            subtest 'subscription expired' => sub {
                subtest 'within 14 days after expiry - is a renewal' => sub {
                    $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                        Customers => [
                            {
                                CustomerExternalReference => 'CUSTOMER_123',
                                Firstname => 'Verity',
                                Surname => 'Wright',
                                CustomertStatus => 'ACTIVATED',
                                ServiceContracts => [
                                    {
                                        # 14 days ago
                                        EndDate => '18/01/2024 12:00',
                                        Reference => $contract_id,
                                        WasteContainerQuantity => 2,
                                        ServiceContractStatus => 'NOACTIVE',
                                        UPRN => '10001',
                                        Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                    },
                                ],
                            },
                        ],
                    } } );

                    $mech->get_ok("/waste/$uprn");
                    unlike $mech->content,
                        qr/Change your brown wheelie bin subscription/,
                        'cannot amend subscription';
                    unlike $mech->content, qr/Renew subscription today/,
                        '"Renew today" notification box not shown';
                    like $mech->content, qr/18 January 2024, subscription overdue/,
                        '"Overdue" message shown';
                    like $mech->content,
                        qr/Renew your brown wheelie bin subscription/,
                        'Renewal link available';

                    $mech->get_ok("/waste/$uprn/garden_renew");
                    $mech->submit_form_ok(
                        {   with_fields => {
                                has_reference => 'Yes',
                                customer_reference => 'CUSTOMER_123',
                            },
                        },
                    );

                    like $mech->content, qr/name="current_bins.*value="2"/s,
                        'Current bins pre-populated';
                    like $mech->content, qr/name="bins_wanted.*value="2"/s,
                        'Wanted bins pre-populated';
                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 1,
                                payment_method => 'credit_card',
                            },
                        }
                    );

                    like $mech->text,
                        qr/Total£$ggw_cost_first_human/, 'correct cost';
                    $mech->waste_submit_check(
                        { with_fields => { tandc => 1 } } );

                    my ( $token, $renew_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
                    check_extra_data_pre_confirm(
                        $renew_report,
                        type         => 'Renew',
                        current_bins => 2,
                        new_bins     => -1,
                        bins_wanted  => 1,
                        customer_external_ref => 'CUSTOMER_123',
                        renew_as_new_subscription => '',
                    );
                    is $renew_report->get_extra_field_value('uprn'), $uprn;
                    is $renew_report->get_extra_field_value('payment'), $ggw_cost_first;
                    is $renew_report->get_extra_field_value('type'), 'renew';

                    $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
                    check_extra_data_post_confirm($renew_report);

                    $mech->clear_emails_ok;
                    FixMyStreet::Script::Reports::send();

                    my @emails = $mech->get_email;
                    my ($to_user) = grep {
                        $mech->get_text_body_from_email($_)
                            =~ /Thank you for renewing your subscription/
                    } @emails;
                    ok $to_user, 'Email sent to user';
                    my $email_body = $mech->get_text_body_from_email($to_user);
                    like $email_body, qr/Number of bin subscriptions: 1/;
                    unlike $email_body, qr/Bins to be delivered/;
                    like $email_body, qr/Bins to be removed: 1/;
                    like $email_body, qr/Total:.*?$ggw_cost_first_human/;

                    $renew_report->delete;

                    subtest 'verification failed - is a new subscription' => sub {
                        $mech->get_ok("/waste/$uprn/garden_renew");

                        $mech->submit_form_ok(
                            {   with_fields => {
                                    has_reference => 'Yes',
                                    customer_reference => 'CUSTOMER_BAD',
                                },
                            },
                        );
                        $mech->submit_form_ok(
                            {   with_fields => {
                                    verifications_first_name => 'Ferrety',
                                    verifications_last_name => 'Wright',
                                    email => 'ferrety@wright.com',
                                },
                            },
                        );

                        like $mech->text,
                            qr/Renew your garden waste subscription/,
                            'Can still renew';
                        like $mech->content, qr/name="current_bins.*value="2"/s,
                            'Current bins pre-populated';
                        like $mech->content, qr/name="bins_wanted.*value="2"/s,
                            'Wanted bins pre-populated';

                        $mech->submit_form_ok(
                            {   with_fields => {
                                    bins_wanted => 2,
                                    payment_method => 'credit_card',
                                },
                            }
                        );
                        $mech->waste_submit_check(
                            { with_fields => { tandc => 1 } } );

                        my ( $token, $renew_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

                        # Should be blank customer_external_reference
                        check_extra_data_pre_confirm(
                            $renew_report,
                            type         => 'New',
                            current_bins => 2,
                            new_bins     => 0,
                            bins_wanted  => 2,
                            customer_external_ref => '',
                            renew_as_new_subscription => 1,
                        );

                        $renew_report->delete;

                    };
                };

                subtest 'Ended more than 14 days but less than 3 months ago - renewal becomes a new signup' => sub {
                    $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                        Customers => [
                            {
                                CustomerExternalReference => 'CUSTOMER_123',
                                Firstname => 'Verity',
                                Surname => 'Wright',
                                CustomertStatus => 'INACTIVE',
                                ServiceContracts => [
                                    {
                                        # Just over 3 months ago - should get ignored
                                        EndDate => '31/10/2023 12:00',
                                        Reference => 'CONTRACT_OLD',
                                        WasteContainerQuantity => 2,
                                        ServiceContractStatus => 'NOACTIVE',
                                        UPRN => '10001',
                                        Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                    },
                                    {
                                        # Just under 3 months ago
                                        EndDate => '01/11/2023 11:00',
                                        Reference => 'CONTRACT_234',
                                        WasteContainerQuantity => 1,
                                        ServiceContractStatus => 'NOACTIVE',
                                        UPRN => '10001',
                                        Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                    },
                                    {
                                        # Just under 3 months ago
                                        EndDate => '01/11/2023 12:00',
                                        Reference => $contract_id,
                                        WasteContainerQuantity => 2,
                                        ServiceContractStatus => 'NOACTIVE',
                                        UPRN => '10001',
                                        Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                    },
                                ],
                            },
                        ],
                    } } );

                    $mech->get_ok("/waste/$uprn");
                    unlike $mech->content,
                        qr/Change your brown wheelie bin subscription/,
                        'cannot amend subscription';
                    unlike $mech->content, qr/Renew subscription today/,
                        '"Renew today" notification box not shown';
                    like $mech->content, qr/1 November 2023, subscription overdue/,
                        '"Overdue" message shown';
                    like $mech->content,
                        qr/Renew your brown wheelie bin subscription/,
                        'Renewal link available';

                    $mech->get_ok("/waste/$uprn/garden_renew");

                    $mech->submit_form_ok(
                        {   with_fields => {
                                has_reference => 'Yes',
                                customer_reference => 'CUSTOMER_123',
                            },
                        },
                    );

                    like $mech->content, qr/name="current_bins.*value="2"/s,
                        'Current bins pre-populated';
                    like $mech->content, qr/name="bins_wanted.*value="2"/s,
                        'Wanted bins pre-populated';

                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 2,
                                payment_method => 'credit_card',
                            },
                        }
                    );
                    $mech->waste_submit_check(
                        { with_fields => { tandc => 1 } } );

                    my ( $token, $renew_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

                    # Should be new signup with customer ref
                    check_extra_data_pre_confirm(
                        $renew_report,
                        type         => 'New',
                        current_bins => 2,
                        new_bins     => 0,
                        bins_wanted  => 2,
                        customer_external_ref => 'CUSTOMER_123',
                        renew_as_new_subscription => 1,
                    );

                    $renew_report->delete;

                };

                subtest 'Ended more than 3 months ago - no renewal option' => sub {
                    $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                        Customers => [
                            {
                                CustomerExternalReference => 'CUSTOMER_123',
                                Firstname => 'Verity',
                                Surname => 'Wright',
                                CustomertStatus => 'INACTIVE',
                                ServiceContracts => [
                                    {
                                        # Just over 3 months ago
                                        EndDate => '31/10/2023 12:00',
                                        Reference => 'CONTRACT_OLD',
                                        WasteContainerQuantity => 2,
                                        ServiceContractStatus => 'NOACTIVE',
                                        UPRN => '10001',
                                        Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                    },
                                ],
                            },
                        ],
                    } } );

                    $mech->get_ok("/waste/$uprn");
                    unlike $mech->content,
                        qr/Change your brown wheelie bin subscription/,
                        'cannot amend subscription';
                    unlike $mech->content, qr/Renew subscription today/,
                        '"Renew today" notification box not shown';
                    unlike $mech->content, qr/subscription overdue/,
                        '"Overdue" message not shown';
                    unlike $mech->content,
                        qr/Renew your brown wheelie bin subscription/,
                        'Renewal link not available';
                };

                subtest 'Inactive DD subscription' => sub {
                    $new_sub_report->set_extra_fields(
                        { name => 'uprn', value => $uprn } ,
                        { name => 'direct_debit_reference', value => 'APIRTM-DEFGHIJ1KL' },
                    );
                    $new_sub_report->set_extra_metadata(
                        direct_debit_customer_id => 'DD_CUSTOMER_123',
                        direct_debit_contract_id => 'DD_CONTRACT_123',
                        direct_debit_reference => 'APIRTM-DEFGHIJ1KL',
                    );
                    $new_sub_report->update;

                    $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                        Customers => [
                            {
                                CustomerExternalReference => 'CUSTOMER_123',
                                Firstname => 'Verity',
                                Surname => 'Wright',
                                CustomertStatus => 'INACTIVE',
                                ServiceContracts => [
                                    {
                                        # 14 days ago
                                        EndDate => '18/01/2024 12:00',
                                        Reference => $contract_id,
                                        WasteContainerQuantity => 2,
                                        ServiceContractStatus => 'NOACTIVE',
                                        UPRN => '10001',
                                        Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Direct debit' } ]
                                    },
                                ],
                            },
                        ],
                    } } );

                    $mech->get_ok("/waste/$uprn");
                    unlike $mech->content,
                        qr/Change your brown wheelie bin subscription/,
                        'cannot amend subscription';

                };
            };
        };
    };

    subtest 'Test bank details form validation' => sub {
        default_mocks();
        $mech->get_ok('/waste/10001/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 1,
            payment_method => 'direct_debit',
            name => 'Test McTest',
            email => 'test@example.net'
        }});

        $mech->content_like(qr/name="first_name"[^>]*value="Test"/);
        $mech->content_like(qr/name="address2"[^>]*value="98a-99b The Court"/);
        $mech->content_like(qr/name="post_code"[^>]*value="DA1 3NP"/);

        my %valid_fields = (
            name_title => 'Mr',
            first_name => 'Test',
            surname => 'McTest',
            address1 => '1 Test Street',
            address2 => 'Test Area',
            post_code => 'DA1 3NP',
            account_holder => 'Test McTest',
            account_number => '12345678',
            sort_code => '12-34-56'
        );

        # Test missing required fields
        my %empty_fields = map { $_ => '' } keys %valid_fields;
        $mech->submit_form_ok({ with_fields => \%empty_fields });
        $mech->content_contains('Name of account holder field is required', 'Shows error for missing account holder name');
        $mech->content_contains('Account number field is required', 'Shows error for missing account number');
        $mech->content_contains('Address line 1 field is required', 'Shows error for missing address line 1');
        $mech->content_contains('Address line 2 field is required', 'Shows error for missing address line 2');
        $mech->content_contains('Title (e.g. Mr, Mrs, Ms, Dr, etc.) field is required', 'Shows error for missing title');
        $mech->content_contains('Postcode field is required', 'Shows error for missing postcode');
        $mech->content_contains('Sort code field is required', 'Shows error for missing sort code');
        $mech->content_contains('Surname field is required', 'Shows error for missing surname');

        # Test invalid account holder name (too long)
        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            account_holder => 'Test McTest 12345678901234567890'
        }});
        $mech->content_contains('Account holder name must be 18 characters or less', 'Shows error for account holder name too long');

        # Test invalid account number (not 8 digits)
        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            account_number => '1234567'
        }});
        $mech->content_contains('Please enter a valid 8 digit account number', 'Shows error for invalid account number');
        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            account_number => '123456789'
        }});
        $mech->content_contains('Please enter a valid 8 digit account number', 'Shows error for invalid account number');

        # Test invalid sort code (not 6 digits)
        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            sort_code => '12345'
        }});
        $mech->content_contains('Please enter a valid 6 digit sort code', 'Shows error for invalid sort code');
        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            sort_code => '1234567'
        }});
        $mech->content_contains('Please enter a valid 6 digit sort code', 'Shows error for invalid sort code');


        # Test bank details that fail Access PaySuite bankcheck API validation
        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            sort_code => '110012' # triggers invalid account number error in mock
        }});
        $mech->content_contains('Account number is invalid.', 'Shows error for invalid account number');

        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            sort_code => '110013' # triggers invalid sort code error in mock
        }});
        $mech->content_contains('Sort code is invalid.', 'Shows error for invalid sort code');

        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            sort_code => '110014' # triggers invalid API key error in mock
        }});
        $mech->content_contains('There was a problem verifying your bank details; please try again', 'Shows generic error');
        $mech->content_lacks('Either the client code or the API key is incorrect.', "Doesn't show API-specific error");

        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            sort_code => '110015' # triggers invalid client error in mock
        }});
        $mech->content_contains('There was a problem verifying your bank details; please try again', 'Shows generic error');
        $mech->content_lacks('Either the client code or the API key is incorrect.', "Doesn't show API-specific error");

        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            sort_code => '110016' # triggers badly formatted account number error in mock
        }});
        $mech->content_contains('There was a problem verifying your bank details; please try again', 'Shows generic error');
        $mech->content_lacks('Either the client code or the API key is incorrect.', "Doesn't show API-specific error");

        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            sort_code => '000000' # triggers non-JSON response in mock
        }});
        $mech->content_contains('There was a problem verifying your bank details; please try again', 'Shows generic error');
        $mech->content_lacks('this is just a plain text string', "Doesn't show API response");


        # Test invalid postcode
        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            post_code => 'NOT A POSTCODE'
        }});
        $mech->content_contains('Please enter a valid postcode', 'Shows error for invalid postcode');

        # Test address line length restrictions
        $mech->submit_form_ok({ with_fields => {
            %valid_fields,
            address1 => 'This address line is way too long and should trigger an error because it exceeds fifty characters',
            address2 => 'This address line is too long and exceeds thirty characters'
        }});
        $mech->content_contains('Address line 1 must be 50 characters or less', 'Shows error for address line 1 too long');
        $mech->content_contains('Address line 2 must be 30 characters or less', 'Shows error for address line 2 too long');

        # Test valid submission
        $mech->submit_form_ok({ with_fields => \%valid_fields });
        $mech->content_contains('Please review the information you’ve provided before you submit your garden subscription', 'Shows success message for valid submission');
    };

    subtest 'Test direct debit submission flow' => sub {
        $mech->clear_emails_ok;
        FixMyStreet::DB->resultset("Problem")->delete_all;

        set_fixed_time('2023-12-29T17:00:00Z');

        my $access_mock = Test::MockModule->new('Integrations::AccessPaySuite');
        my ($customer_params, $contract_params);
        $access_mock->mock('create_customer', sub {
            my ($self, $params) = @_;
            $customer_params = $params;
            return { Id => 'CUSTOMER123' };
        });
        $access_mock->mock('create_contract', sub {
            my ($self, $customer_id, $params) = @_;
            $contract_params = $params;
            return { Id => 'CONTRACT123', DirectDebitRef => 'APIRTM-DEFGHIJ1KL' };
        });
        $access_mock->mock('get_customer_by_customer_ref', sub {
            return undef;
        });

        $mech->get_ok('/waste/10001/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 1,
            payment_method => 'direct_debit',
            name => 'Test McTest',
            email => 'test@example.net'
        }});

        # Submit bank details form
        $mech->submit_form_ok({ with_fields => {
            name_title => 'Mr',
            first_name => 'Test',
            surname => 'McTest',
            address1 => '1 Test Street',
            address2 => 'Test Area',
            post_code => 'DA1 1AA',
            account_holder => 'Test McTest',
            account_number => '12345678',
            sort_code => '123456'
        }});

        $mech->content_contains('Please review the information you’ve provided before you submit your garden subscription');

        $mech->content_contains('Test McTest');
        my $discount_human = sprintf('%.2f', ($ggw_cost_first - $ggw_first_bin_discount) / 100);
        $mech->content_contains('£' . $discount_human);
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        ok $report, "Found the report";
        my $id = $report->id;

        # Check customer creation parameters
        is_deeply $customer_params, {
            customerRef => $id,
            email => 'test@example.net',
            title => 'Mr',
            firstName => 'Test',
            surname => 'McTest',
            postCode => 'DA1 1AA',
            accountNumber => '12345678',
            bankSortCode => '123456',
            accountHolderName => 'Test McTest',
            line1 => '1 Test Street',
            line2 => 'Test Area',
            line3 => '1a-2b The Avenue',
            line4 => 'Little Bexlington',
        }, 'Customer parameters are correct';

        # Check contract creation parameters
        is_deeply $contract_params, {
            scheduleId => 123,
            isGiftAid => 0,
            terminationType => 'Until further notice',
            atTheEnd => 'Switch to further notice',
            paymentDayInMonth => 28,
            paymentMonthInYear => 1,
            amount => $discount_human,
            start => '2024-01-28T17:00:00.000',
            additionalReference => "10001",
        }, 'Contract parameters are correct';

        $mech->content_contains('Your Direct Debit has been set up successfully');
        $mech->content_contains('Direct Debit Mandate');

        $mech->back;
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_lacks('Your Direct Debit has been set up successfully');
        $mech->content_contains('You have already submitted this form');
        $mech->content_contains('To avoid duplicate submissions, this form cannot be resubmitted.');
        $mech->content_lacks('Change answers');
        $mech->content_lacks('Please review the information you’ve provided before you submit your garden subscription');

        is $report->get_extra_metadata('direct_debit_customer_id'), 'CUSTOMER123', 'Correct customer ID';
        is $report->get_extra_metadata('direct_debit_contract_id'), 'CONTRACT123', 'Correct contract ID';
        is $report->get_extra_metadata('direct_debit_reference'), 'APIRTM-DEFGHIJ1KL', 'Correct payer reference';
        is $report->state, 'confirmed', 'Report is confirmed';

        is $report->get_extra_field_value('direct_debit_reference'),
            'APIRTM-DEFGHIJ1KL', 'Reference set as extra field';
        is $report->get_extra_field_value('direct_debit_start_date'),
            '28/01/2024', 'Start date set as extra field';

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $email_body = $mech->get_text_body_from_email($emails[1]);
        like $email_body, qr/Number of bin subscriptions: 1/;
        like $email_body, qr/Bins to be delivered: 1/;
        like $email_body, qr/Total:.*?$discount_human/;
        $mech->clear_emails_ok;
    };

    subtest 'Test direct debit setup with empty email' => sub {
        $mech->delete_problems_for_body($body->id);
        set_fixed_time('2023-12-29T17:00:00Z');

        my $access_mock = Test::MockModule->new('Integrations::AccessPaySuite');
        my ($customer_params, $contract_params);
        $access_mock->mock('create_customer', sub {
            my ($self, $params) = @_;
            $customer_params = $params;
            return { Id => 'CUSTOMER123' };
        });
        $access_mock->mock('create_contract', sub {
            my ($self, $customer_id, $params) = @_;
            $contract_params = $params;
            return { Id => 'CONTRACT123', DirectDebitRef => 'APIRTM-DEFGHIJ1KL' };
        });
        $access_mock->mock('get_customer_by_customer_ref', sub {
            return undef;
        });

        # Log in as staff user, as they are allowed to submit the form with an empty email
        $mech->log_in_ok($staff_user->email);

        $mech->get_ok('/waste/10001/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 1,
            payment_method => 'direct_debit',
            name => 'Test McTest',
            phone => '07700900002',
            email => '', # Empty email
        }});

        # Submit bank details form
        $mech->submit_form_ok({ with_fields => {
            name_title => 'Mr',
            first_name => 'Test',
            surname => 'McTest',
            address1 => '1 Test Street',
            address2 => 'Test Area',
            post_code => 'DA1 1AA',
            account_holder => 'Test McTest',
            account_number => '12345678',
            sort_code => '123456'
        }});

        $mech->content_contains('Please review the information you’ve provided before you submit your garden subscription');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        ok $report, "Found the report";

        # Check default email was used
        is $customer_params->{email}, 'gardenwaste@' . $body->get_cobrand_handler->admin_user_domain, 'Default email was used';

        $mech->content_contains('Your Direct Debit has been set up successfully');
        $mech->content_contains('Direct Debit Mandate');
    };

    $mech->delete_problems_for_body($body->id);

    subtest 'correct amount shown on existing DD subscriptions' => sub {
        my $discount_human = sprintf('%.2f', ($ggw_cost_first - $ggw_first_bin_discount) / 100);
        foreach my $status ("Pending", "Paid") {
            subtest "Payment status: $status" => sub {
                default_mocks();
                set_fixed_time('2024-02-01T00:00:00');

                my ($dd_report) = $mech->create_problems_for_body(
                    1,
                    $body->id,
                    'Garden Subscription - New',
                    {   category    => 'Garden Subscription',
                        title       => 'Garden Subscription - New',
                        external_id => 'Agile-CONTRACT_123',
                    },
                );
                $dd_report->set_extra_fields(
                    { name => 'uprn', value => 10001 },
                    { name  => 'payment_method', value => 'direct_debit' },
                );
                $dd_report->set_extra_metadata(
                    direct_debit_customer_id => 'DD_CUSTOMER_123' );
                $dd_report->update;

                my $access_mock
                    = Test::MockModule->new('Integrations::AccessPaySuite');

                $access_mock->mock(
                    get_contracts => sub {
                        return [
                            {   Status => (
                                    $status eq 'Pending'
                                    ? 'Inactive'
                                    : 'Active'
                                )
                            }
                        ];
                    },
                );

                $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                    Customers => [
                        {
                            CustomerExternalReference => 'CUSTOMER_123',
                            CustomertStatus => 'ACTIVATED',
                            ServiceContracts => [
                                {
                                    EndDate => '12/12/2024 12:21',
                                    ServiceContractStatus => 'NOACTIVE',
                                    UPRN => '10001',
                                    Payments => [
                                        {
                                            PaymentStatus => "Paid",
                                            PaymentMethod => "Direct debit",
                                            Amount => 55
                                        }
                                    ]
                                },
                                {
                                    EndDate => '12/12/2025 12:21',
                                    Reference => 'CONTRACT_123',
                                    ServiceContractStatus => 'ACTIVE',
                                    UPRN => '10001',
                                    Payments => [
                                        {
                                            PaymentStatus => $status,
                                            PaymentMethod => "Direct debit",
                                            Amount => $discount_human
                                        }
                                    ]
                                },
                            ],
                        },
                    ],
                } } );

                $mech->log_in_ok( $user->email );

                $mech->get_ok('/waste/10001');
                like $mech->text, qr/Brown wheelie bin/;
                like $mech->text, qr/Next collectionPending/;
                like $mech->text, qr/Subscription.*$discount_human per year/;

                set_fixed_time('2025-12-01T00:00:00');
                $mech->get_ok('/waste/10001');
                $mech->content_lacks('Renew your');
                $mech->content_contains( $status eq 'Pending'
                    ? 'pending direct debit subscription'
                    : 'existing direct debit subscription' );
            }
        }
    };

    subtest 'cancel garden subscription' => sub {
        default_mocks();
        set_fixed_time('2024-02-01T00:00:00');
        my $tomorrow = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y' )->format_datetime( DateTime->now->add(days => 1) );

        $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
            Customers => [
                {
                    CustomerExternalReference => 'CUSTOMER_123',
                    Firstname => 'VERITY',
                    Surname => 'wright',
                    Email => 'verity@wright.com',
                    CustomertStatus => 'ACTIVATED',
                    ServiceContracts => [
                        {
                            EndDate => '12/12/2025 12:21',
                            ServiceContractStatus => 'ACTIVE',
                            UPRN => '10001',
                            WasteContainerQuantity => 2,
                            Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                        },
                    ],
                },
            ],
        } } );

        # Staff can see all reports at a property and that can confuse the cancellation
        # as it sees the direct debit set up above and tries to cancel the DD
        $mech->delete_problems_for_body($body->id);

        subtest 'standard user' => sub {
            $mech->log_in_ok( $user->email );
            $mech->get_ok('/waste/10001/garden_cancel');
            like $mech->text, qr/customer reference number/, 'On customer ref page';
        };

        $mech->log_in_ok( $staff_user->email );

        subtest 'with Agile data only' => sub {
            $mech->get_ok('/waste/10001');
            like $mech->text, qr/Brown wheelie bin/;
            like $mech->text, qr/Next collectionPending/;

            $mech->get_ok('/waste/10001/garden_cancel');
            $mech->submit_form_ok(
                {   with_fields => {
                        has_reference => 'Yes',
                        customer_reference => 'CUSTOMER_BAD',
                    },
                },
            );
            like $mech->text, qr/Incorrect customer reference/,
                'error message shown on next page if bad reference';
            $mech->submit_form_ok(
                {   with_fields => {
                        verifications_first_name => 'Verity',
                        verifications_last_name => 'Wright',
                        email => 'test@example.org',
                    },
                }
            );
            $mech->submit_form_ok(
                {   with_fields => {
                        reason  => 'Other',
                        reason_further_details => 'Burnt all my leaves',
                    },
                }
            );

            like $mech->text, qr/Cancel your garden waste subscription/;
            $mech->submit_form_ok(
                {   with_fields => {
                        confirm => 1,
                    },
                }
            );
            like $mech->text, qr/Your subscription has been cancelled/,
                'form submitted OK';

            my $report
                = FixMyStreet::DB->resultset('Problem')->order_by('-id')
                ->first;
            my $str = 'Your reference number is ' .  $report->id;
            like $mech->text, qr/$str/, 'report ID displayed';

            is $report->state, 'confirmed',
                'cancellation report auto-confirmed';
            is $report->get_extra_field_value('customer_external_ref'),
                'CUSTOMER_123';
            is $report->get_extra_field_value('due_date'),
                $tomorrow;
            is $report->get_extra_field_value('reason'),
                'Other: Burnt all my leaves';

            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();

            my @emails = $mech->get_email;
            my ($to_user) = grep {
                $mech->get_text_body_from_email($_)
                    =~ /You have cancelled your garden waste collection service/
            } @emails;
            ok $to_user, 'Email sent to user';

        };

        subtest 'with Whitespace data' => sub {
            $bexley_mocks{whitespace}->mock(
                'GetSiteCollections',
                sub {
                    [   {   SiteServiceID          => 1,
                            ServiceItemDescription => 'Garden waste',
                            ServiceItemName => 'GA-140',  # Garden 140 ltr Bin
                            ServiceName          => 'Brown Wheelie Bin',
                            NextCollectionDate   => '2024-02-07T00:00:00',
                            SiteServiceValidFrom => '2024-01-01T00:00:00',
                            SiteServiceValidTo   => '0001-01-01T00:00:00',

                            RoundSchedule => 'RND-1 Mon',
                        }
                    ];
                }
            );

            $mech->get_ok('/waste/10001');
            like $mech->content, qr/waste-service-subtitle.*Garden waste/s;

            $mech->get_ok('/waste/10001/garden_cancel');
            $mech->submit_form_ok(
                {   with_fields => {
                        has_reference => 'Yes',
                        customer_reference => 'CUSTOMER_123',
                    },
                },
            );
            $mech->submit_form_ok(
                {   with_fields => {
                        reason  => 'Price',
                    },
                }
            );

            like $mech->text, qr/Cancel your garden waste subscription/;
            $mech->submit_form_ok(
                {   with_fields => {
                        confirm => 1,
                    },
                }
            );
            like $mech->text, qr/Your subscription has been cancelled/,
                'form submitted OK';

            my $report
                = FixMyStreet::DB->resultset('Problem')->order_by('-id')
                ->first;

            is $report->state, 'confirmed',
                'cancellation report auto-confirmed';
            is $report->get_extra_field_value('customer_external_ref'),
                'CUSTOMER_123';
            is $report->get_extra_field_value('due_date'),
                $tomorrow;
            is $report->get_extra_field_value('reason'),
                'Price';

            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();

            my @emails = $mech->get_email;
            my ($to_user) = grep {
                $mech->get_text_body_from_email($_)
                    =~ /You have cancelled your garden waste collection service/
            } @emails;
            ok $to_user, 'Email sent to user';

        };

        subtest 'verification failed' => sub {
            $mech->get_ok('/waste/10001/garden_cancel');
            $mech->submit_form_ok(
                {   with_fields => {
                        has_reference => 'Yes',
                        customer_reference => 'CUSTOMER_BAD',
                    },
                },
            );
            $mech->submit_form_ok(
                {   with_fields => {
                        verifications_first_name => 'Verity',
                        verifications_last_name => 'Wrong',
                        email => 'test@example.org',
                    },
                }
            );
            like $mech->text, qr/Verification failed/, 'verification failed page';
        };

        subtest 'Original sub paid via direct debit' => sub {
            $mech->delete_problems_for_body($body->id);

            my $access_mock = Test::MockModule->new('Integrations::AccessPaySuite');
            $access_mock->mock( cancel_plan => 'CANCEL_REF_123' );

            my $uprn = 10001;
            my $contract_id = 'CONTRACT_123';

            $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                Customers => [
                    {
                        CustomerExternalReference => 'CUSTOMER_123',
                        Firstname => 'Verity',
                        Surname => 'Wright',
                        CustomertStatus => 'ACTIVATED',
                        ServiceContracts => [
                            {
                                EndDate => '12/12/2025 12:21',
                                Reference => $contract_id,
                                WasteContainerQuantity => 2,
                                ServiceContractStatus => 'ACTIVE',
                                UPRN => '10001',
                            },
                        ],
                    },
                ],
            } } );

            my ($new_sub_report) = $mech->create_problems_for_body(
                1,
                $body->id,
                '',
                {   category    => 'Garden Subscription',
                    title       => 'Garden Subscription - New',
                    external_id => "Agile-$contract_id",
                    user_id     => $user->id,
                },
            );
            $new_sub_report->set_extra_fields(
                { name => 'uprn', value => $uprn },
                { name => 'payment_method', value => 'direct_debit' },
            );
            $new_sub_report->update;
            FixMyStreet::Script::Reports::send();

            $mech->get_ok('/waste/10001/garden_cancel');
            $mech->submit_form_ok(
                {   with_fields => {
                        has_reference => 'Yes',
                        customer_reference => 'CUSTOMER_BAD',
                    },
                },
            );
            $mech->submit_form_ok(
                {   with_fields => {
                        verifications_first_name => 'Verity',
                        verifications_last_name => 'Wright',
                        email => 'test@example.org',
                    },
                }
            );
            $mech->submit_form_ok(
                {   with_fields => {
                        reason  => 'Price',
                    },
                }
            );
            $mech->submit_form_ok(
                {   with_fields => {
                        confirm => 1,
                    },
                }
            );
            like $mech->text, qr/Your subscription has been cancelled/,
                'form submitted OK';

            my $report
                = FixMyStreet::DB->resultset('Problem')->order_by('-id')
                ->first;
            is $report->state, 'confirmed',
                'cancellation report auto-confirmed';

            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();

            my @emails = $mech->get_email;
            my ($to_user) = grep {
                $mech->get_text_body_from_email($_)
                    =~ /You have cancelled your garden waste collection service/
            } @emails;
            ok $to_user, 'Email sent to user';

        };

    };

    subtest 'Test direct debit cancellation' => sub {
        $mech->clear_emails_ok;

        # Log in as a staff user
        $mech->log_in_ok($staff_user->email);

        my $contract_id = 'CONTRACT123';

        my ($new_sub_report) = $mech->create_problems_for_body(
            1,
            $body->id,
            'Garden Subscription - New',
            {   category    => 'Garden Subscription',
                title => 'Garden Subscription - New',
                external_id => "Agile-$contract_id",
                user => $user,
            },
        );

        $new_sub_report->set_extra_metadata(direct_debit_contract_id => $contract_id);
        $new_sub_report->set_extra_fields(
            { name => 'uprn', value => 10001 },
            { name => 'payment_method', value => 'direct_debit' },
        );
        $new_sub_report->update;

        FixMyStreet::Script::Reports::send();

        # Set up the mock for Whitespace to return garden waste service
        $bexley_mocks{whitespace}->mock(
            'GetSiteCollections',
            sub {
                [   {   SiteServiceID          => 1,
                        ServiceItemDescription => 'Garden waste',
                        ServiceItemName => 'GA-140',  # Garden 140 ltr Bin
                        ServiceName          => 'Brown Wheelie Bin',
                        NextCollectionDate   => '2024-02-07T00:00:00',
                        SiteServiceValidFrom => '2024-01-01T00:00:00',
                        SiteServiceValidTo   => '0001-01-01T00:00:00',
                        RoundSchedule => 'RND-1 Mon',
                    }
                ];
            }
        );

        # Set up the mock for Agile to return customer data
        $bexley_mocks{agile}->mock( 'CustomerSearch', sub {
            my ($self, $uprn) = @_;
            # Make sure the UPRN is what's expected, otherwise return empty
            return {} unless $uprn eq '10001';

            return {
                Customers => [
                    {
                        CustomerExternalReference => 'CUSTOMER_123',
                        Firstname => 'Verity',
                        Surname => 'Wright',
                        CustomertStatus => 'ACTIVATED',
                        ServiceContracts => [
                            {
                                EndDate => '12/12/2025 12:21',
                                ServiceContractStatus => 'ACTIVE',
                                UPRN => '10001',
                                Reference => $contract_id,
                                WasteContainerQuantity => 2,
                                Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ],
                            },
                        ],
                    },
                ],
            };
        });

        # Set up the mock for AccessPaySuite
        my $access_mock = Test::MockModule->new('Integrations::AccessPaySuite');
        my $archive_contract_called = 0;
        my $archived_contract_id;

        $access_mock->mock('archive_contract', sub {
            my ($self, $contract_id) = @_;
            $archive_contract_called = 1;
            $archived_contract_id = $contract_id;
            return {}; # Success response
        });

        # Navigate to the property page and verify garden waste service is shown
        $mech->get_ok('/waste/10001');
        like $mech->content, qr/waste-service-subtitle.*Garden waste/s, 'Garden waste service is shown';

        # Navigate to the cancellation page
        $mech->get_ok('/waste/10001/garden_cancel');

        # Submit the cancellation form
        $mech->submit_form_ok(
            {   with_fields => {
                    has_reference => 'Yes',
                    customer_reference => 'CUSTOMER_123',
                },
            },
        );
        $mech->submit_form_ok(
            {   with_fields => {
                    reason  => 'Other',
                    reason_further_details => 'No longer needed',
                },
            }
        );

        like $mech->text, qr/Cancel your garden waste subscription/, 'On cancellation page';
        $mech->submit_form_ok(
            {   with_fields => {
                    confirm => 1,
                },
            }
        );

        # Verify success message
        like $mech->text, qr/Your subscription has been cancelled/, 'Cancellation success message shown';

        # Get the cancellation report
        my $cancel_report = FixMyStreet::DB->resultset('Problem')->search(
            { category => 'Cancel Garden Subscription' },
        )->order_by('-id')->first;

        # Verify the report details
        ok $cancel_report, 'Cancellation report created';
        is $cancel_report->get_extra_field_value('customer_external_ref'), 'CUSTOMER_123', 'Customer reference set correctly';
        is $cancel_report->get_extra_field_value('reason'), 'Other: No longer needed', 'Reason set correctly';

        # Verify the archive_contract was called with the right parameters
        is $archive_contract_called, 1, 'archive_contract was called';
        is $archived_contract_id, $contract_id, 'correct contract_id was passed';
    };

    subtest 'renew garden subscription with direct debit that was previously paid by credit card' => sub {
        $mech->delete_problems_for_body($body->id);

        default_mocks();
        set_fixed_time('2024-02-01T00:00:00Z');

        my $uprn = 10001;
        my $contract_id = 'CARD_CONTRACT_123';

        # Create a report representing a subscription that was previously paid by credit card
        my ($existing_sub_report) = $mech->create_problems_for_body(
            1,
            $body->id,
            'Garden Subscription - New',
            {
                created => DateTime->now->subtract( years => 1 ),
                category    => 'Garden Subscription',
                external_id => "Agile-$contract_id",
                title => 'Garden Subscription - New',
            },
        );
        $existing_sub_report->set_extra_fields(
            { name => 'uprn', value => $uprn },
            { name => 'payment_method', value => 'credit_card' }, # This indicates it was paid by credit card
        );
        $existing_sub_report->update;
        FixMyStreet::Script::Reports::send();

        # Mock Agile data to show it's due for renewal
        $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
            Customers => [
                {
                    CustomerExternalReference => 'CUSTOMER_123',
                    Firstname => 'Verity',
                    Surname => 'Wright',
                    CustomertStatus => 'ACTIVATED',
                    ServiceContracts => [
                        {
                            # Within the 42-day renewal window
                            EndDate => '14/03/2024 12:00',
                            Reference => $contract_id,
                            WasteContainerQuantity => 2,
                            ServiceContractStatus => 'ACTIVE',
                            UPRN => '10001',
                            Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ],
                        },
                    ],
                },
            ],
        } } );

        # Set up Whitespace data for the garden waste service
        $bexley_mocks{whitespace}->mock(
            'GetSiteCollections',
            sub {
                [
                    {
                        SiteServiceID          => 1,
                        ServiceItemDescription => 'Garden waste',
                        ServiceItemName => 'GA-140',  # Garden 140 ltr Bin
                        ServiceName          => 'Brown Wheelie Bin',
                        NextCollectionDate   => '2024-02-07T00:00:00',
                        SiteServiceValidFrom => '2024-01-01T00:00:00',
                        SiteServiceValidTo   => '0001-01-01T00:00:00',
                        RoundSchedule => 'RND-1 Mon',
                    }
                ];
            }
        );

        # Mock AccessPaySuite for direct debit setup
        my $access_mock = Test::MockModule->new('Integrations::AccessPaySuite');
        my ($customer_params, $contract_params);
        $access_mock->mock('create_customer', sub {
            my ($self, $params) = @_;
            $customer_params = $params;
            return { Id => 'CUSTOMER123' };
        });
        $access_mock->mock('create_contract', sub {
            my ($self, $customer_id, $params) = @_;
            $contract_params = $params;
            return { Id => 'CONTRACT123', DirectDebitRef => 'APIRTM-DEFGHIJ1KL' };
        });
        $access_mock->mock('get_customer_by_customer_ref', sub {
            return undef; # First-time direct debit customer
        });

        # Start the renewal process
        $mech->get_ok("/waste/$uprn");
        like $mech->content, qr/Renew subscription today/,
            '"Renew today" notification box shown';
        like $mech->content, qr/14 March 2024, soon due for renewal/,
            '"Due soon" message shown';

        $mech->get_ok("/waste/$uprn/garden_renew");
        $mech->submit_form_ok(
            {   with_fields => {
                    has_reference => 'Yes',
                    customer_reference => 'CUSTOMER_123',
                },
            },
        );

        like $mech->content, qr/name="current_bins.*value="2"/s,
            'Current bins pre-populated';

        # Now choose direct debit as payment method
        $mech->submit_form_ok(
            {   with_fields => {
                    bins_wanted => 2, # Keep same number of bins
                    payment_method => 'direct_debit', # Switch to direct debit
                },
            }
        );

        # We should be on the direct debit details form now
        $mech->text_contains(
            'Please provide your bank account information so we can set up your Direct Debit mandate',
            'On DD details form',
        );

        # Submit bank details
        $mech->submit_form_ok({ with_fields => {
            name_title => 'Mr',
            first_name => 'Test',
            surname => 'McTest',
            address1 => '1 Test Street',
            address2 => 'Test Area',
            post_code => 'DA1 1AA',
            account_holder => 'Test McTest',
            account_number => '12345678',
            sort_code => '123456'
        }});

        # Check summary page
        $mech->content_contains('Please review the information you’ve provided before you submit your garden subscription');
        $mech->content_contains('Verity Wright');
        my $discount_human = sprintf('%.2f', ($ggw_cost_first + $ggw_cost - $ggw_first_bin_discount) / 100);
        $mech->content_contains('£' . $discount_human);
        # Submit the form
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        # Check that we got a successful setup page
        $mech->content_contains('Your Direct Debit has been set up successfully');
        $mech->content_contains('Direct Debit Mandate');

        # Check customer params
        is $customer_params->{accountHolderName}, 'Test McTest', 'Correct account holder name';
        is $customer_params->{accountNumber}, 12345678, 'Correct account number';
        is $customer_params->{bankSortCode}, 123456, 'Correct sort code';
        is $customer_params->{firstName}, 'Test', 'Correct first name';
        is $customer_params->{line1}, '1 Test Street', 'Correct address line 1';
        is $customer_params->{line2}, 'Test Area', 'Correct address line 2';
        is $customer_params->{postCode}, 'DA1 1AA', 'Correct post code';
        is $customer_params->{surname}, 'McTest', 'Correct surname';
        is $customer_params->{title}, 'Mr', 'Correct title';

        # Check the report was created correctly
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        ok $report, "Found the report";

        # Check a couple of contract params
        is $contract_params->{additionalReference}, '10001', 'Correct additional reference';
        is $contract_params->{amount}, $discount_human, 'Correct amount';

        is $report->title, "Garden Subscription - Renew", "Correct title";
        is $report->category, "Garden Subscription", "Correct category";
        is $report->get_extra_field_value('payment_method'), 'direct_debit', "Correct payment method";
        is $report->get_extra_field_value('customer_external_ref'), 'CUSTOMER_123', "Customer reference preserved";
        is $report->get_extra_field_value('type'), 'renew', "Marked as renewal";

        is $report->get_extra_metadata('direct_debit_customer_id'), 'CUSTOMER123', 'Correct customer ID';
        is $report->get_extra_metadata('direct_debit_contract_id'), 'CONTRACT123', 'Correct contract ID';
        is $report->get_extra_metadata('direct_debit_reference'), 'APIRTM-DEFGHIJ1KL', 'Correct payer reference';
        is $report->state, 'confirmed', 'Report is confirmed';
    };

    subtest 'Staff garden waste subscription uses paye.net with custom narrative' => sub {
        $sent_params = {};
        $call_params = {};
        default_mocks();
        $mech->log_in_ok($staff_user->email);

        $mech->get_ok('/waste/10001/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Staff Test',
            email => 'staff@example.org'
        } });
        $mech->content_contains('Staff Test');
        $mech->content_contains('£' . $ggw_cost_first_human);
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my ($token, $report, $report_id) = get_report_from_redirect($sent_params->{returnUrl});

        is $sent_params->{narrative}, "Garden Waste Service Payment - Reference: " . $report_id . " Contract: 10001",
            'Custom narrative was used for paye.net payment';
    };

    subtest 'Bin days page' => sub {
        subtest 'Garden sub with credit card payment' => sub {
            $mech->delete_problems_for_body($body->id);
            set_fixed_time('2024-02-01T00:00:00Z');
            default_mocks();

            my ($cc_report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Garden Subscription - New',
                {   category => 'Garden Subscription',
                    title    => 'Garden Subscription - New',
                    external_id => 'Agile-CONTRACT_123',
                    created => '2024-01-31T00:00:00Z',
                },
            );
            $cc_report->set_extra_fields(
                { name => 'uprn', value => 10001 },
                { name => 'payment_method', value => 'credit_card' },
            );
            $cc_report->update;

            subtest 'No Agile or Whitespace data' => sub {
                $mech->get_ok('/waste/10001');
                like $mech->text,
                    qr/You do not have a Garden waste collection/,
                    '"no garden waste" message shown';
            };

            subtest 'Agile data, but no Whitespace data' => sub {
                $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                    Customers => [
                        {
                            CustomerExternalReference => 'CUSTOMER_123',
                            CustomertStatus => 'ACTIVATED',
                            ServiceContracts => [
                                {
                                    EndDate => '01/02/2025 00:00',
                                    Reference => 'CONTRACT_123',
                                    WasteContainerQuantity => 1,
                                    ServiceContractStatus => 'ACTIVE',
                                    UPRN => '10001',
                                    Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                },
                            ],
                        },
                    ],
                } } );

                $mech->content_unlike(
                    qr/You have a pending garden subscription\./,
                    'Overall subscription not shown as pending',
                );
                $mech->get_ok('/waste/10001');
                like $mech->text,
                    qr/Frequency.*Pending/,
                    'garden waste shown with pending Whitespace values';
                like $mech->text,
                    qr/75\.00 per year \(1 bin\)/,
                    'garden waste shown with calculated cost';
                like $mech->text,
                    qr/Manage garden waste bins/,
                    'management link shown';
                like $mech->text,
                    qr/Payment methodDebit or Credit Card/,
                    'payment method displayed';
            };

            subtest 'Whitespace data, but no Agile data' => sub {
                default_mocks();

                $bexley_mocks{whitespace}->mock(
                    'GetSiteCollections',
                    sub {
                        [   {   SiteServiceID          => 1,
                                ServiceItemDescription =>
                                    'Non-recyclable waste',
                                ServiceItemName      => 'PC-180',
                                ServiceName          => 'Blue Wheelie Bin',
                                NextCollectionDate   => '2024-02-07T00:00:00',
                                SiteServiceValidFrom => '2024-01-01T00:00:00',
                                SiteServiceValidTo   => '0001-01-01T00:00:00',

                                RoundSchedule        => 'RND-1 Mon',
                            },
                            {   SiteServiceID          => 2,
                                ServiceItemDescription => 'Garden waste',
                                ServiceItemName        =>
                                    'GA-140',    # Garden 140 ltr Bin
                                ServiceName          => 'Brown Wheelie Bin',
                                NextCollectionDate   => '2024-02-07T00:00:00',
                                SiteServiceValidFrom => '2024-01-01T00:00:00',
                                SiteServiceValidTo   => '0001-01-01T00:00:00',

                                RoundSchedule => 'RND-1 Mon',
                            }
                        ];
                    }
                );

                $mech->get_ok('/waste/10001');
                like $mech->text,
                    qr/Status: You do not have a Garden waste collection/,
                    '"no garden waste" message shown';
                like $mech->text,
                    qr/Subscribe to garden waste collection service/,
                    'garden subscription link shown';
            };

            subtest 'Agile and Whitespace data' => sub {
                $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                    Customers => [
                        {
                            CustomerExternalReference => 'CUSTOMER_123',
                            CustomertStatus => 'ACTIVATED',
                            ServiceContracts => [
                                {
                                    EndDate => '01/02/2025 00:00',
                                    Reference => 'CONTRACT_123',
                                    WasteContainerQuantity => 1,
                                    ServiceContractStatus => 'ACTIVE',
                                    UPRN => '10001',
                                    Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                                },
                            ],
                        },
                    ],
                } } );

                $mech->get_ok('/waste/10001');
                like $mech->text,
                    qr/Frequency.*Weekly/,
                    'garden waste shown with Whitespace values';
                like $mech->text,
                    qr/75\.00 per year \(1 bin\)/,
                    'garden waste shown with calculated cost';
                unlike $mech->text,
                    qr/Your subscription is soon due for renewal/,
                    'renewal warning not shown';
            };

            $mech->delete_problems_for_body($body->id);

            subtest 'Due for renewal' => sub {
                set_fixed_time('2025-01-01T00:00:00Z');

                $mech->get_ok('/waste/10001');
                like $mech->text,
                    qr/Your subscription is soon due for renewal/,
                    'renewal warning shown';
                like $mech->text,
                    qr/Avoid disruption to your service/,
                    'default message shown';
                like $mech->content,
                    qr/value="Renew subscription today"/,
                    'renewal button shown';
                like $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'renewal link shown';
            };

            subtest 'Renewal overdue' => sub {
                set_fixed_time('2025-03-01T00:00:00Z');

                $mech->get_ok('/waste/10001');
                unlike $mech->text,
                    qr/Your subscription is soon due for renewal/,
                    'renewal warning not shown';
                like $mech->content,
                    qr/subscription overdue/,
                    'overdue message shown';
                like $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'renewal link still shown';
            };
        };

        subtest 'Garden sub with direct debit payment' => sub {
            $mech->delete_problems_for_body($body->id);
            set_fixed_time('2024-02-01T00:00:00Z');
            default_mocks();

            my ($dd_report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Garden Subscription - New',
                {   category => 'Garden Subscription',
                    title    => 'Garden Subscription - New',
                    external_id => 'Agile-CONTRACT_123',
                },
            );
            $dd_report->set_extra_fields(
                { name => 'uprn', value => 10001 },
                { name => 'payment_method', value => 'direct_debit' },
            );
            $dd_report->set_extra_metadata(
                direct_debit_customer_id => 'DD_CUSTOMER_123' );
            $dd_report->update;

            $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
                Customers => [
                    {
                        CustomerExternalReference => 'CUSTOMER_123',
                        CustomertStatus => 'ACTIVATED',
                        ServiceContracts => [
                            {
                                EndDate => '01/02/2025 00:00',
                                Reference => 'CONTRACT_123',
                                WasteContainerQuantity => 1,
                                ServiceContractStatus => 'ACTIVE',
                                UPRN => '10001',
                                Payments => [
                                    {   PaymentStatus => 'Paid',
                                        Amount        => '100',
                                        PaymentMethod => 'Direct debit',
                                    }
                                ]
                            },
                        ],
                    },
                ],
            } } );

            $bexley_mocks{whitespace}->mock(
                'GetSiteCollections',
                sub {
                    [   {   SiteServiceID          => 1,
                            ServiceItemDescription =>
                                'Non-recyclable waste',
                            ServiceItemName      => 'PC-180',
                            ServiceName          => 'Green Wheelie Bin',
                            NextCollectionDate   => '2024-02-07T00:00:00',
                            SiteServiceValidFrom => '2024-01-01T00:00:00',
                            SiteServiceValidTo   => '0001-01-01T00:00:00',

                            RoundSchedule        => 'RND-1 Mon',
                        },
                        {   SiteServiceID          => 2,
                            ServiceItemDescription => 'Garden waste',
                            ServiceItemName        =>
                                'GA-140',    # Garden 140 ltr Bin
                            ServiceName          => 'Brown Wheelie Bin',
                            NextCollectionDate   => '2024-02-07T00:00:00',
                            SiteServiceValidFrom => '2024-01-01T00:00:00',
                            SiteServiceValidTo   => '0001-01-01T00:00:00',

                            RoundSchedule => 'RND-1 Mon',
                        }
                    ];
                }
            );

            my $access_mock
                = Test::MockModule->new('Integrations::AccessPaySuite');

            subtest 'DD pending' => sub {
                $access_mock->mock(
                    get_contracts => sub {
                        is $_[1], 'DD_CUSTOMER_123', 'correct customer ID';
                        return [ { Status => 'Inactive' } ];
                    },
                );

                $mech->get_ok('/waste/10001');
                $mech->content_like(
                    qr/You have a pending garden subscription\./,
                    'Subscription shown as pending',
                );
                like $mech->text,
                    qr/Payment methodDirect Debit/,
                    'payment method displayed';
                like $mech->text,
                    qr/This property has a pending direct debit subscription/,
                    'pending DD message shown';
            };

            subtest 'DD active' => sub {
                $access_mock->mock(
                    get_contracts => sub { [ { Status => 'Active' } ] },
                );

                $mech->get_ok('/waste/10001');
                $mech->content_unlike(
                    qr/You have a pending garden subscription\./,
                    'Subscription no longer shown as pending',
                );
                like $mech->text,
                    qr/This property has an existing direct debit subscription which will renew automatically/,
                    'active DD message shown';
            };

# TODO
            # subtest 'DD payment failed' => sub {

            # };

            subtest 'Due for renewal' => sub {
                set_fixed_time('2025-01-01T00:00:00Z');

                $mech->get_ok('/waste/10001');
                $mech->content_lacks('Your subscription is soon due for renewal');
                $mech->content_contains('This property has an existing direct debit subscription which will renew automatically');
                $mech->content_lacks('value="Renew subscription today"');
                $mech->content_lacks('Renew your brown wheelie bin subscription');
            };

            subtest 'Renewal overdue' => sub {
                set_fixed_time('2025-03-01T00:00:00Z');

                $mech->get_ok('/waste/10001');
                unlike $mech->text,
                    qr/Your subscription is soon due for renewal/,
                    'renewal warning not shown';
                unlike $mech->content,
                    qr/subscription overdue/,
                    'overdue message not shown';
                unlike $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'renewal link not shown';
                like $mech->text,
                    qr/This property has an existing direct debit subscription which will renew automatically/,
                    'active DD message still shown';
            };
        };
    };

    subtest 'Parent property scenarios' => sub {
        my $child_uprn = 10002;
        my $parent_uprn = 10001;
        my $parent_site_id = 999;

        default_mocks();
        $bexley_mocks{whitespace}->mock( 'GetSiteInfo', sub {
            my ($self, $uprn) = @_;
            return {
                AccountSiteUPRN => $child_uprn,
                Site            => { SiteParentID => $parent_site_id }
            } if $uprn == $child_uprn;
            return { AccountSiteUPRN => $parent_uprn, Site => {} }; # Parent has no parent
        });
        $bexley_mocks{whitespace}->mock( 'GetAccountSiteID', sub {
            my ($self, $site_id) = @_;
            return { AccountSiteUprn => $parent_uprn } if $site_id == $parent_site_id;
            return {};
        });

        # Scenario 1: Parent property exists, but child has its own services (kerbside)
        subtest 'Kerbside with parent UPRN' => sub {
            $bexley_mocks{whitespace}->mock( 'GetSiteCollections', sub {
                my ($self, $uprn) = @_;
                # Child has its own service
                return [
                    {   ServiceItemName      => 'PC-180',
                        NextCollectionDate   => '2024-02-07T00:00:00',
                        ServiceName          => 'Blue Bin',
                        SiteServiceValidFrom => '2000-01-01T00:00:00',
                        SiteServiceValidTo   => '0001-01-01T00:00:00',
                        RoundSchedule        => 'RND-1 Mon'
                    }
                ] if $uprn == $child_uprn;
                return [];
            });

            $mech->get_ok("/waste/$child_uprn");
            $mech->content_contains(
                'Sign up for a garden waste collection',
                'Sign-up button for garden shown',
            );
            $mech->content_contains(
                'Subscribe to garden waste collection service',
                'Sidebar garden sign-up link shown',
            );
        };

        # Scenario 2: Parent property exists, child has NO services (communal)
        subtest 'Communal with parent UPRN' => sub {
            $bexley_mocks{whitespace}->mock( 'GetSiteCollections', sub {
                my ($self, $uprn) = @_;
                return [] if $uprn == $child_uprn; # Child has no services
                # Parent has services
                return [
                    {   ServiceItemName      => 'RES-180',
                        NextCollectionDate   => '2024-02-07T00:00:00',
                        ServiceName          => 'Green Bin',
                        SiteServiceValidFrom => '2000-01-01T00:00:00',
                        SiteServiceValidTo   => '0001-01-01T00:00:00',
                        RoundSchedule        => 'RND-1 Mon'
                    }
                ] if $uprn == $parent_uprn;
                return [];
            });

            $mech->get_ok("/waste/$child_uprn");
            $mech->content_lacks(
                'Sign up for a garden waste collection',
                'Sign-up button for garden not shown',
            );
            $mech->content_lacks(
                'Subscribe to garden waste collection service',
                'Sidebar garden sign-up link not shown',
            );
        };
    };
};

my $archive_contract_called;
my $archived_contract_id;
my $accesspaysuite_mock = Test::MockModule->new('Integrations::AccessPaySuite');
$accesspaysuite_mock->mock('archive_contract' => sub
    {
        my ($self, $contract_id) = @_;
        $archive_contract_called = 1;
        $archived_contract_id = $contract_id;
        cancel_plan => 'CANCEL_REF_123'
    });
$bexley_mocks{agile}->mock( 'CustomerSearch', sub { {
    Customers => [
        {
            CustomerExternalReference => 'DD_CUSTOMER_123',
            CustomertStatus => 'ACTIVATED',
            ServiceContracts => [
                {
                    EndDate => '01/02/2025 00:00',
                    Reference => 'CONTRACT_123',
                    WasteContainerQuantity => 1,
                    ServiceContractStatus => 'ACTIVE',
                    UPRN => '10001',
                    Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => 'Credit/Debit Card' } ]
                },
            ],
        },
    ],
} } );


$mech->delete_problems_for_body($body->id);
my ($dd_report) = $mech->create_problems_for_body(
    1,
    $body->id,
    'Garden Subscription - New',
    {   category => 'Garden Subscription',
        title    => 'Garden Subscription - New',
        external_id => 'Agile-CONTRACT_123',
    },
);
$dd_report->set_extra_fields(
    { name => 'uprn', value => 10001 },
    { name => 'payment_method', value => 'direct_debit' },
);
$dd_report->set_extra_metadata(
    direct_debit_contract_id => 'DD_CONTRACT_123',
    direct_debit_customer_id => 'DD_CUSTOMER_123',
    direct_debit_reference   => 'APIRTM_123',
);
$dd_report->update;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        waste => { bexley => 1 },
        whitespace => { bexley => {
            url => 'https://example.net/',
        } },
        agile => { bexley => { url => 'test' } },
        payment_gateway => {
            bexley => {
                dd_endpoint => "dd_payment/endpoint",
                dd_apikey => "dd_api_key",
                dd_client_code => "dd_client_code",
                log_ident => "ident",
            }
        },
    },
}, sub {
    subtest 'contract cancelled by webhook' => sub {
        FixMyStreet::Script::Reports::send();
        $mech->clear_emails_ok;
        is $mech->post(
            '/waste/access_paysuite/contract_updates',
            Content_Type => 'application/json',
            Content      => encode_json(
                {
                    Entity     => 'contract',
                    Id         => 'DD_CONTRACT_123',
                    NewStatus  => 'Cancelled',
                    ReportMessage =>
                        'Contract Cancelled because of ADDACS code 1 (Instruction Cancelled)',
                }
            ),
        )->code, 200, 'successful';
        is $archive_contract_called, 1, 'archive_contract was called';
        is $archived_contract_id, 'DD_CONTRACT_123', 'correct contract_id was passed';
        FixMyStreet::Script::Reports::send();
        my $cancel =  FixMyStreet::DB->resultset('Problem')->find({ category => 'Cancel Garden Subscription' });
        is $cancel->title, 'Garden Subscription - Cancel', 'Correct title for cancellation report';
        is $cancel->name, 'Test User', 'User name on cancellation report';
        is $cancel->send_state, 'sent', 'Cancellation report has been created and sent';
        is $cancel->get_extra_metadata('direct_debit_contract_id'), 'DD_CONTRACT_123';
        is $cancel->get_extra_field_value('customer_external_ref'), 'DD_CUSTOMER_123';
        my @emails = $mech->get_email;
        is @emails, 2, "Notice sent to user for cancellation and to Bexley";
    };
};

done_testing;

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
        category => 'Garden Subscription',
        payment_method => 'credit_card',
        ref_type => 'scp',
        state => 'unconfirmed',
        type => 'New',
        customer_external_ref => '',
        renew_as_new_subscription => '',

        # Quantities
        current_bins => 0,
        new_bins => 1,
        bins_wanted => 1,

        @_,
    );

    $report->discard_changes;
    is $report->category, $params{category}, 'correct category on report';
    is $report->title, "Garden Subscription - $params{type}", 'correct title on report';
    is $report->get_extra_field_value('payment_method'), $params{payment_method}, 'correct payment method on report';

    is $report->get_extra_field_value('current_containers'), $params{current_bins}, 'correct current_containers';
    is $report->get_extra_field_value('new_containers'), $params{new_bins}, 'correct new_containers';
    is $report->get_extra_field_value('total_containers'), $params{bins_wanted}, 'correct total_containers';
    is $report->get_extra_field_value('customer_external_ref'), $params{customer_external_ref}, 'correct customer ref';
    is $report->get_extra_field_value('renew_as_new_subscription'), $params{renew_as_new_subscription}, 'correct renew_as_new_subscription flag';

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
    is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
}
