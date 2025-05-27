use Test::MockModule;
use Test::MockObject;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use List::MoreUtils qw(firstidx);

FixMyStreet::App->log->disable('info', 'error');
END { FixMyStreet::App->log->enable('info', 'error'); }

my $addr_mock = Test::MockModule->new('BexleyAddresses');
# We don't actually read from the file, so just put anything that is a valid path
$addr_mock->mock( 'database_file', '/' );
my $dbi_mock = Test::MockModule->new('DBI');
$dbi_mock->mock( 'connect', sub {
    my $dbh = Test::MockObject->new;
    $dbh->mock( 'selectrow_hashref', sub { {} } );
    return $dbh;
} );

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
);
create_contact(
    { category => 'Cancel Garden Subscription', email => 'garden_cancel@example.com' },
    { code => 'customer_external_ref', required => 1, automated => 'hidden_field' },
    { code => 'due_date', required => 1, automated => 'hidden_field' },
    { code => 'reason', required => 1, automated => 'hidden_field' },
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'server' },
);

my $whitespace_mock = Test::MockModule->new('Integrations::Whitespace');
my $agile_mock = Test::MockModule->new('Integrations::Agile');
sub default_mocks {
    # These are overridden for some tests
    $whitespace_mock->mock('GetSiteCollections', sub {
        [ {
            SiteServiceID          => 1,
            ServiceItemDescription => 'Non-recyclable waste',
            ServiceItemName => 'RES-180',
            ServiceName          => 'Green Wheelie Bin',
            NextCollectionDate   => '2024-02-07T00:00:00',
            SiteServiceValidFrom => '2000-01-01T00:00:00',
            SiteServiceValidTo   => '0001-01-01T00:00:00',
            RoundSchedule => 'RND-1 Mon',
        } ];
    });
    $whitespace_mock->mock(
        'GetCollectionByUprnAndDate',
        sub {
            my ( $self, $property_id, $from_date ) = @_;
            return [];
        }
    );
    $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub { });
    $whitespace_mock->mock( 'GetInCabLogsByUprn', sub { });
    $whitespace_mock->mock( 'GetSiteInfo', sub { {
        AccountSiteID   => 1,
        AccountSiteUPRN => 10001,
        Site            => {
            SiteShortAddress => ', 1, THE AVENUE, DA1 3NP',
            SiteLatitude     => 51.466707,
            SiteLongitude    => 0.181108,
        },
    } });
    $whitespace_mock->mock( 'GetAccountSiteID', sub {});
    $whitespace_mock->mock( 'GetSiteWorksheets', sub {});
    $whitespace_mock->mock( 'GetWorksheetDetailServiceItems', sub { });

    $agile_mock->mock( 'CustomerSearch', sub { {} } );
};

default_mocks();

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

        $agile_mock->mock( 'CustomerSearch', sub { {
            Customers => [
                {
                    CustomerExternalReference => 'CUSTOMER_123',
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

        $whitespace_mock->mock(
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
            like $mech->text, qr/Change your garden waste subscription/, 'modification permitted';
        };

        subtest 'staff logged in' => sub {
            $mech->log_in_ok( $staff_user->email );

            $mech->get_ok("/waste/$uprn");
            like $mech->content, qr/Change your brown wheelie bin subscription/, 'modify link present';

            $mech->get_ok("/waste/$uprn/garden_modify");
            like $mech->text, qr/Change your garden waste subscription/, 'modification permitted';
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
                like $mech->text, qr/Change your garden waste subscription/, 'modification permitted';
                like $mech->content, qr/current_bins.*value="2"/s, 'correct number of current bins prefilled';

                subtest 'add bins' => sub {
                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 4,
                                name        => 'Trevor Trouble',
                            },
                        }
                    );

                    like $mech->text, qr/Garden waste collection4 bins/, 'correct bin total in summary';
                    like $mech->text, qr/Total.240\.00/, 'correct payment total in summary';
                    like $mech->text, qr/Total to pay today.110\.00/, 'correct today-payment in summary';
                    like $mech->text, qr/Your nameTrevor Trouble/, 'correct name in summary';
                    my $email = $user->email;
                    like $mech->text, qr/$email/, 'correct email in summary';

                    $mech->waste_submit_check({ with_fields => { tandc => 1 } });

                    my ( $token, $modify_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

                    is $sent_params->{items}[0]{amount}, 11000, 'correct amount used';
                    check_extra_data_pre_confirm(
                        $modify_report,
                        type         => 'Amend',
                        current_bins => 2,
                        new_bins     => 2,
                        bins_wanted  => 4,
                    );
                    is $modify_report->get_extra_field_value('type'), 'amend',
                        'correct report type';
                    is $modify_report->get_extra_field_value(
                        'customer_external_ref'), 'CUSTOMER_123',
                        'correct customer_external_ref';
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
                    like $email_body, qr/Total:.*?110\.00/;
                };

                subtest 'remove bins' => sub {
                    $mech->get_ok("/waste/$uprn/garden_modify");
                    like $mech->content, qr/current_bins.*value="2"/s, 'correct number of current bins prefilled'; # No change in Agile

                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 1,
                                name        => 'Trevor Trouble',
                            },
                        }
                    );

                    like $mech->text, qr/Garden waste collection1 bin/, 'correct bin total in summary';
                    like $mech->text, qr/Total.75\.00/, 'correct payment total in summary';
                    like $mech->text, qr/Total to pay today.0\.00/, 'correct today-payment in summary';
                    like $mech->text, qr/Your nameTrevor Trouble/, 'correct name in summary';
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
                    );
                    is $modify_report->get_extra_field_value('type'), 'amend',
                        'correct report type';
                    is $modify_report->get_extra_field_value(
                        'customer_external_ref'), 'CUSTOMER_123',
                        'correct customer_external_ref';
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
                            name        => 'DD Modifier',
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
# TODO
# like $mech->text, qr/Total to pay today.0\.00/,
    # 'correct today-payment in summary (zero for DD amend)';
                like $mech->text, qr/Your nameDD Modifier/,
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
                is $modify_report->state, 'confirmed', 'Amend report: state correct (confirmed for DD amend)';

                $access_mock->unmock_all;
            };

        };
    };

    subtest 'renew garden subscription' => sub {
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
            },
        );
        $new_sub_report->set_extra_fields(
            { name => 'uprn', value => $uprn } );
        $new_sub_report->update;
        FixMyStreet::Script::Reports::send();

        subtest 'with active contract elsewhere' => sub {
            $agile_mock->mock( 'CustomerSearch', sub { {
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
                                ServiceContractStatus => 'INACTIVE',
                                UPRN => '10001',
                                Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => '' } ]
                            },
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
            $whitespace_mock->mock( 'GetSiteCollections', sub { [] } );
            $agile_mock->mock( 'CustomerSearch', sub { {
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
                                Payments => [ { PaymentStatus => 'Paid', Amount => '100', PaymentMethod => '' } ]
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
            $whitespace_mock->mock(
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
                $agile_mock->mock( 'CustomerSearch', sub { {
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
                unlike $mech->content, qr/Renew subscription today/,
                    '"Renew today" notification box not shown';
                unlike $mech->content, qr/14 March 2024, soon due for renewal/,
                    '"Due soon" message not shown';
                unlike $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'Renewal link not available';
            };

            subtest 'within renewal window' => sub {
                $agile_mock->mock( 'CustomerSearch', sub { {
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
                like $mech->text, qr/Frequency.*Wednesday 7 February 2024/,
                    'Details are not pending because we have Whitespace data';

                $mech->get_ok("/waste/$uprn/garden_renew");
                like $mech->content, qr/name="current_bins.*value="2"/s,
                    'Current bins pre-populated';
                like $mech->content, qr/name="bins_wanted.*value="2"/s,
                    'Wanted bins pre-populated';

                subtest 'requesting more bins' => sub {
                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 3,
                                payment_method => 'credit_card',
                                name => 'Trevor Trouble',
                                email => 'trevor@trouble.com',
                                phone => '+4407111111111',
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
                    );
                    is $renew_report->get_extra_field_value('uprn'), $uprn;
                    is $renew_report->get_extra_field_value('payment'), $ggw_cost_first + 2 * $ggw_cost;
                    is $renew_report->get_extra_field_value('type'), 'renew';
                    is $renew_report->get_extra_field_value(
                        'customer_external_ref'), 'CUSTOMER_123';

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
                };

                subtest 'requesting fewer bins' => sub {
                    $mech->get_ok("/waste/$uprn/garden_renew");

                    like $mech->content, qr/name="current_bins.*value="2"/s,
                        'Current bins pre-populated';
                    like $mech->content, qr/name="bins_wanted.*value="2"/s,
                        'Wanted bins pre-populated';

                    $mech->submit_form_ok(
                        {   with_fields => {
                                bins_wanted => 1,
                                payment_method => 'credit_card',
                                name => 'Trevor Trouble',
                                email => 'trevor@trouble.com',
                                phone => '+4407111111111',
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
                    );
                    is $renew_report->get_extra_field_value('uprn'), $uprn;
                    is $renew_report->get_extra_field_value('payment'), $ggw_cost_first;
                    is $renew_report->get_extra_field_value('type'), 'renew';
                    is $renew_report->get_extra_field_value(
                        'customer_external_ref'), 'CUSTOMER_123';

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
                };

            };

            $mech->delete_problems_for_body($body->id);

            subtest 'too early' => sub {
                $agile_mock->mock( 'CustomerSearch', sub { {
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
                like $mech->content, qr/Renewal.*15 March 2024/s,
                    'Renewal date shown';
                unlike $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'Renewal link unavailable';
            };

            subtest 'subscription expired -  renewal treated as new sub' => sub {
                $agile_mock->mock( 'CustomerSearch', sub { {
                    Customers => [
                        {
                            CustomerExternalReference => 'CUSTOMER_123',
                            CustomertStatus => 'ACTIVATED',
                            ServiceContracts => [
                                {
                                    # Yesterday
                                    EndDate => '31/01/2024 12:00',
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
                unlike $mech->content, qr/Renew subscription today/,
                    '"Renew today" notification box not shown';
                like $mech->content, qr/31 January 2024, subscription overdue/,
                    '"Overdue" message shown';
                like $mech->content,
                    qr/Renew your brown wheelie bin subscription/,
                    'Renewal link available';

                $mech->get_ok("/waste/$uprn/garden_renew");
                like $mech->content, qr/name="current_bins.*value="2"/s,
                    'Current bins pre-populated';
                like $mech->content, qr/name="bins_wanted.*value="2"/s,
                    'Wanted bins pre-populated';

                $mech->submit_form_ok(
                    {   with_fields => {
                            bins_wanted => 1,
                            payment_method => 'credit_card',
                            name => 'Trevor Trouble',
                            email => 'trevor@trouble.com',
                            phone => '+4407111111111',
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
                );
                is $renew_report->get_extra_field_value('uprn'), $uprn;
                is $renew_report->get_extra_field_value('payment'), $ggw_cost_first;
                is $renew_report->get_extra_field_value('type'), 'renew';
                is $renew_report->get_extra_field_value(
                    'customer_external_ref'), 'CUSTOMER_123';

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
            };
        };
    };

    subtest 'Test bank details form validation' => sub {
        default_mocks();
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 1,
            payment_method => 'direct_debit',
            name => 'Test McTest',
            email => 'test@example.net'
        }});

        my %valid_fields = (
            name_title => 'Mr',
            first_name => 'Test',
            surname => 'McTest',
            address1 => '1 Test Street',
            address2 => 'Test Area',
            post_code => 'DA1 1AA',
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

        $mech->get_ok('/waste/12345/garden');
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
            line3 => undef,
            line4 => undef,
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
        $mech->content_contains('Direct Debit mandate');

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

        $mech->get_ok('/waste/12345/garden');
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
        $mech->content_contains('Direct Debit mandate');
    };

    $mech->delete_problems_for_body($body->id);

    subtest 'correct amount shown on existing DD subscriptions' => sub {
        my $discount_human = sprintf('%.2f', ($ggw_cost_first - $ggw_first_bin_discount) / 100);
        foreach my $status ("Pending", "Paid") {
            subtest "Payment status: $status" => sub {
                default_mocks();
                set_fixed_time('2024-02-01T00:00:00');

                $agile_mock->mock( 'CustomerSearch', sub { {
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
                $mech->content_contains('existing direct debit subscription');
            }
        }
    };

    subtest 'cancel garden subscription' => sub {
        default_mocks();
        set_fixed_time('2024-02-01T00:00:00');
        my $tomorrow = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y' )->format_datetime( DateTime->now->add(days => 1) );

        $agile_mock->mock( 'CustomerSearch', sub { {
            Customers => [
                {
                    CustomerExternalReference => 'CUSTOMER_123',
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

        $mech->log_in_ok( $user->email );
        subtest 'staff only' => sub {
            $mech->get_ok('/waste/10001/garden_cancel');
            is $mech->uri->path, "/waste/10001";
        };
        $mech->log_in_ok( $staff_user->email );

        subtest 'with Agile data only' => sub {
            $mech->get_ok('/waste/10001');
            like $mech->text, qr/Brown wheelie bin/;
            like $mech->text, qr/Next collectionPending/;

            $mech->get_ok('/waste/10001/garden_cancel');
            like $mech->text, qr/Cancel your garden waste subscription/;

            $mech->submit_form_ok(
                {   with_fields => {
                        name => 'Name McName',
                        email => 'test@example.org',
                        reason  => 'Other',
                        reason_further_details => 'Burnt all my leaves',
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
            $whitespace_mock->mock(
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
            like $mech->text, qr/Cancel your garden waste subscription/;

            $mech->submit_form_ok(
                {   with_fields => {
                        name => 'Name McName',
                        email => 'test@example.org',
                        reason  => 'Price',
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

        subtest 'Original sub paid via direct debit' => sub {
            $mech->delete_problems_for_body($body->id);

            my $access_mock = Test::MockModule->new('Integrations::AccessPaySuite');
            $access_mock->mock( cancel_plan => 'CANCEL_REF_123' );

            my $uprn = 10001;
            my $contract_id = 'CONTRACT_123';

            $agile_mock->mock( 'CustomerSearch', sub { {
                Customers => [
                    {
                        CustomerExternalReference => 'CUSTOMER_123',
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
                        name => 'Name McName',
                        email => 'test@example.org',
                        reason  => 'Price',
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
        $whitespace_mock->mock(
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
        $agile_mock->mock( 'CustomerSearch', sub {
            my ($self, $uprn) = @_;
            # Make sure the UPRN is what's expected, otherwise return empty
            return {} unless $uprn eq '10001';

            return {
                Customers => [
                    {
                        CustomerExternalReference => 'CUSTOMER_123',
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

        like $mech->text, qr/Cancel your garden waste subscription/, 'On cancellation page';

        # Submit the cancellation form
        $mech->submit_form_ok(
            {   with_fields => {
                    name => 'Name McName',
                    email => 'test@example.org',
                    reason  => 'Other',
                    reason_further_details => 'No longer needed',
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
        $agile_mock->mock( 'CustomerSearch', sub { {
            Customers => [
                {
                    CustomerExternalReference => 'CUSTOMER_123',
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
        $whitespace_mock->mock(
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
        like $mech->content, qr/name="current_bins.*value="2"/s,
            'Current bins pre-populated';

        # Now choose direct debit as payment method
        $mech->submit_form_ok(
            {   with_fields => {
                    bins_wanted => 2, # Keep same number of bins
                    payment_method => 'direct_debit', # Switch to direct debit
                    name => 'Test McTest',
                    email => 'test@example.net',
                    phone => '+4407111111111',
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
        $mech->content_contains('Test McTest');
        my $discount_human = sprintf('%.2f', ($ggw_cost_first + $ggw_cost - $ggw_first_bin_discount) / 100);
        $mech->content_contains('£' . $discount_human);
        # Submit the form
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        # Check that we got a successful setup page
        $mech->content_contains('Your Direct Debit has been set up successfully');
        $mech->content_contains('Direct Debit mandate');

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
                    # 20+ days ago, to stop this report from being picked up as
                    # a 'pending_subscription'
                    created => '2024-01-01T00:00:00Z',
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
                $agile_mock->mock( 'CustomerSearch', sub { {
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
                    qr/Frequency.*Pending/,
                    'garden waste shown with pending Whitespace values';
                like $mech->text,
                    qr/100\.00 per year \(1 bin\)/,
                    'garden waste shown with Agile values';
                like $mech->text,
                    qr/Manage garden waste bins/,
                    'management link shown';
            };

            subtest 'Whitespace data, but no Agile data' => sub {
                default_mocks();

                $whitespace_mock->mock(
                    'GetSiteCollections',
                    sub {
                        [   {   SiteServiceID          => 1,
                                ServiceItemDescription =>
                                    'Non-recyclable waste',
                                ServiceItemName      => 'RES-180',
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

                $mech->get_ok('/waste/10001');
                like $mech->text,
                    qr/Status: You do not have a Garden waste collection/,
                    '"no garden waste" message shown';
                like $mech->text,
                    qr/Subscribe to garden waste collection service/,
                    'garden subscription link shown';
            };

            subtest 'Agile and Whitespace data' => sub {
                $agile_mock->mock( 'CustomerSearch', sub { {
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
                    qr/100\.00 per year \(1 bin\)/,
                    'garden waste shown with Agile values';
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

            my ($cc_report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Garden Subscription - New',
                {   category => 'Garden Subscription',
                    title    => 'Garden Subscription - New',
                    external_id => 'Agile-CONTRACT_123',
                },
            );
            $cc_report->set_extra_fields(
                { name => 'uprn', value => 10001 },
                { name => 'payment_method', value => 'direct_debit' },
            );
            $cc_report->set_extra_metadata(direct_debit_customer_id => 'DD_CUSTOMER_123');
            $cc_report->update;

            $agile_mock->mock( 'CustomerSearch', sub { {
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

            $whitespace_mock->mock(
                'GetSiteCollections',
                sub {
                    [   {   SiteServiceID          => 1,
                            ServiceItemDescription =>
                                'Non-recyclable waste',
                            ServiceItemName      => 'RES-180',
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
                like $mech->text,
                    qr/This property has a pending direct debit subscription/,
                    'pending DD message shown';
            };

            subtest 'DD active' => sub {
                $access_mock->mock(
                    get_contracts => sub { [ { Status => 'Active' } ] },
                );

                $mech->get_ok('/waste/10001');
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
                like $mech->content,
                    qr/subscription overdue/,
                    'overdue message shown';
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
        $whitespace_mock->mock( 'GetSiteInfo', sub {
            my ($self, $uprn) = @_;
            return {
                AccountSiteUPRN => $child_uprn,
                Site            => { SiteParentID => $parent_site_id }
            } if $uprn == $child_uprn;
            return { AccountSiteUPRN => $parent_uprn, Site => {} }; # Parent has no parent
        });
        $whitespace_mock->mock( 'GetAccountSiteID', sub {
            my ($self, $site_id) = @_;
            return { AccountSiteUprn => $parent_uprn } if $site_id == $parent_site_id;
            return {};
        });

        # Scenario 1: Parent property exists, but child has its own services (kerbside)
        subtest 'Kerbside with parent UPRN' => sub {
            $whitespace_mock->mock( 'GetSiteCollections', sub {
                my ($self, $uprn) = @_;
                # Child has its own service
                return [
                    {   ServiceItemName      => 'RES-180',
                        NextCollectionDate   => '2024-02-07T00:00:00',
                        ServiceName          => 'Green Bin',
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
            $whitespace_mock->mock( 'GetSiteCollections', sub {
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

    subtest 'Test AccessPaySuite create_request' => sub {
        my $aps = Integrations::AccessPaySuite->new(config => { api_key => 'test-api-key', endpoint => 'http://example.com' });

        my $req = $aps->create_request('POST', 'http://example.com/test', { param1 => 'value1', param2 => 'value2' });
        is $req->header('Content-Length'), length($req->content), 'Content-Length matches content length';
        is $req->header('Content-Type'), 'application/x-www-form-urlencoded', 'Content-Type is set correctly';
        like $req->content, qr/param1=value1/, 'param1 is correct';
        like $req->content, qr/param2=value2/, 'param2 is correct';
        is $req->method, 'POST', 'Method is correct';
        is $req->uri, 'http://example.com/test', 'URI is correct';
        like $req->header('User-Agent'), qr/WasteWorks by SocietyWorks/, 'User-Agent is correct';
        is $req->header('ApiKey'), 'test-api-key', 'ApiKey is correct';
        is $req->header('Accept'), 'application/json', 'Accept is correct';
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
        category => 'Garden Subscription',
        payment_method => 'credit_card',
        ref_type => 'scp',
        state => 'unconfirmed',
        type => 'New',

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
