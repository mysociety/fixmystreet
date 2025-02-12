use Test::MockModule;
use Test::MockObject;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use List::MoreUtils qw(firstidx);

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $addr_mock = Test::MockModule->new('BexleyAddresses');
# We don't actually read from the file, so just put anything that is a valid path
$addr_mock->mock( 'database_file', '/' );
my $dbi_mock = Test::MockModule->new('DBI');
$dbi_mock->mock( 'connect', sub {
    my $dbh = Test::MockObject->new;
    $dbh->mock( 'selectrow_hashref', sub { {} } );
    return $dbh;
} );

my $agile_mock = Test::MockModule->new('Integrations::Agile');
$agile_mock->mock( 'CustomerSearch', sub { {} } );

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
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
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
sub default_mocks {
    # These are overridden for some tests
    $whitespace_mock->mock('GetSiteCollections', sub { });
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
};

default_mocks();

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
            ggw_cost_first => 7500,
            ggw_cost => 5500,
            cc_url => 'http://example.org/cc_submit',
            scpID => 1234,
            hmac_id => 1234,
            hmac => 1234,
            paye_siteID => 1234,
            paye_hmac_id => 1234,
            paye_hmac => 1234,
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
        $mech->content_like(qr#Total to pay now: £<span[^>]*>75.00#, "initial cost set correctly");
        is $mech->value('current_bins'), 1, "current bins is set to 1";
    };

    subtest 'check new sub credit card payment' => sub {
        my $test = {
            month => '01',
            pounds_cost => '130.00',
            pence_cost => '13000'
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
        check_extra_data_pre_confirm($new_report, new_bin_type => 1, new_quantity => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");

        check_extra_data_post_confirm($new_report);

        $mech->content_like(qr#/waste/10001">Show upcoming#, "contains link to bin page");

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        TODO: {
            local $TODO = 'Quantity not yet read in _garden_data.html';
            like $body, qr/Number of bin subscriptions: 2/;
        }
        like $body, qr/Bins to be delivered: 2/;
        like $body, qr/Total:.*?$test->{pounds_cost}/;
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
        $mech->content_contains('£75.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 7500, 'correct amount used';
        check_extra_data_pre_confirm($new_report, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        TODO: {
            local $TODO = 'Quantity not yet read in _garden_data.html';
            like $body, qr/Number of bin subscriptions: 1/;
        }
        unlike $body, qr/Bins to be delivered/;
        like $body, qr/Total:.*?75.00/;
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
        $mech->content_contains('£75.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 7500, 'correct amount used';
        check_extra_data_pre_confirm($new_report, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token?STATUS=9&PAYID=54321");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        TODO: {
            local $TODO = 'Quantity not yet read in _garden_data.html';
            like $body, qr/Number of bin subscriptions: 1/;
        }
        like $body, qr/Bins to be removed: 1/;
        like $body, qr/Total:.*?75.00/;
    };

    subtest 'cancel garden subscription' => sub {
        set_fixed_time('2024-02-01T00:00:00');

        $agile_mock->mock( 'CustomerSearch', sub { {
            Customers => [
                {
                    CustomerExternalReference => 'CUSTOMER_123',
                    ServiceContracts => [
                        {
                            EndDate => '12/12/2025 12:21',
                        },
                    ],
                },
            ],
        } } );

        $mech->log_in_ok( $user->email );

        subtest 'with Agile data only' => sub {
            $mech->get_ok('/waste/10001');
            like $mech->text, qr/Brown wheelie bin/;
            like $mech->text, qr/Next collectionPending/;

            $mech->get_ok('/waste/10001/garden_cancel');
            like $mech->text, qr/Cancel your garden waste subscription/;

            $mech->submit_form_ok(
                {   with_fields => {
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

            is $report->get_extra_field_value('customer_external_ref'),
                'CUSTOMER_123';
            is $report->get_extra_field_value('due_date'),
                '12/12/2025';
            is $report->get_extra_field_value('reason'),
                'Other: Burnt all my leaves';

            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();

            my @emails = $mech->get_email;
            my $body = $mech->get_text_body_from_email($emails[1]);
            like $body, qr/You have cancelled your garden waste collection service/;
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

            is $report->get_extra_field_value('customer_external_ref'),
                'CUSTOMER_123';
            is $report->get_extra_field_value('due_date'),
                '12/12/2025';
            is $report->get_extra_field_value('reason'),
                'Other: Burnt all my leaves';

            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();

            my @emails = $mech->get_email;
            my $body = $mech->get_text_body_from_email($emails[1]);
            like $body, qr/You have cancelled your garden waste collection service/;
        };

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
        category => 'Garden Subscription',
        @_
    );
    $report->discard_changes;
    is $report->category, $params{category}, 'correct category on report';
    is $report->title, "Garden Subscription - $params{type}", 'correct title on report';
    is $report->get_extra_field_value('payment_method'), $params{payment_method}, 'correct payment method on report';
    TODO: {
        local $TODO = 'Fields (not these values) not yet set';
        is $report->get_extra_field_value('Paid_Collection_Container_Quantity'), $params{quantity}, 'correct bin count';
        is $report->get_extra_field_value('Paid_Collection_Container_Type'), $params{bin_type}, 'correct bin type';
        is $report->get_extra_field_value('Container_Quantity'), $params{new_quantity}, 'correct bin count';
        is $report->get_extra_field_value('Container_Type'), $params{new_bin_type}, 'correct bin type';
    }
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
