use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2480, 'Kingston upon Thames Council', {}, { cobrand => 'kingston' });
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
    { code => 'Subscription_Details_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Subscription_Details_Containers', required => 1, automated => 'hidden_field' },
    { code => 'Bin_Delivery_Detail_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Bin_Delivery_Detail_Container', required => 1, automated => 'hidden_field' },
    { code => 'Bin_Delivery_Detail_Containers', required => 1, automated => 'hidden_field' },
    { code => 'current_containers', required => 1, automated => 'hidden_field' },
    { code => 'new_containers', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'pro_rata', required => 0, automated => 'hidden_field' },
    { code => 'admin_fee', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Cancel Garden Subscription', email => 'garden_cancel@example.com'},
    { code => 'Bin_Delivery_Detail_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Bin_Delivery_Detail_Container', required => 1, automated => 'hidden_field' },
    { code => 'Bin_Delivery_Detail_Containers', required => 1, automated => 'hidden_field' },
    { code => 'Subscription_End_Date', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
);

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

sub garden_waste_no_bins {
    return [ {
        Id => 1001,
        ServiceId => 405,
        ServiceName => 'Food waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 400,
            TaskTypeId => 2238,
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                ScheduleDescription => 'every other Monday',
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
        ServiceId => 409,
        ServiceName => 'Garden waste collection',
        ServiceTasks => ''
    } ];
}

sub garden_waste_only_refuse_sacks {
    return [ {
        Id => 1001,
        ServiceId => 405,
        ServiceName => 'Refuse collection',
        ServiceTasks => { ServiceTask => {
            Id => 400,
            TaskTypeId => 2242,
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                ScheduleDescription => 'every other Monday',
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
        ServiceId => 409,
        ServiceName => 'Garden waste collection',
        ServiceTasks => ''
    } ];
}

# Have a subscription with both refuse and garden sacks in it;
# Currently these are in separate Echos but tests have the same mock,
# and this will be like this when they are in the same Echo
sub garden_waste_with_sacks {
    my $garden_sacks = _garden_waste_service_units(1, 'sack');
    my $refuse_sacks = garden_waste_only_refuse_sacks();
    return [ $refuse_sacks->[0], $garden_sacks->[0] ];
}

sub garden_waste_bin_with_refuse_sacks {
    my $garden_sacks = _garden_waste_service_units(1, 'bin');
    my $refuse_sacks = garden_waste_only_refuse_sacks();
    return [ $refuse_sacks->[0], $garden_sacks->[0] ];
}

sub garden_waste_one_bin {
    my $refuse_bin = garden_waste_no_bins();
    my $garden_bin = _garden_waste_service_units(1, 'bin');
    return [ $refuse_bin->[0], $garden_bin->[0] ];
}

sub garden_waste_two_bins {
    my $refuse_bin = garden_waste_no_bins();
    my $garden_bins = _garden_waste_service_units(2, 'bin');
    return [ $refuse_bin->[0], $garden_bins->[0] ];
}

sub _garden_waste_service_units {
    my ($bin_count, $type) = @_;

    my $bin_type_id = $type eq 'sack' ? 28 : 26;

    return [ {
        Id => 1002,
        ServiceId => 409,
        ServiceName => 'Garden waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 405,
            TaskTypeId => 2247,
            Data => { ExtensibleDatum => [ {
                DatatypeName => 'SLWP - Containers',
                ChildData => { ExtensibleDatum => [ {
                    DatatypeName => 'Quantity',
                    Value => $bin_count,
                }, {
                    DatatypeName => 'Container Type',
                    Value => $bin_type_id,
                } ] },
            } ] },
            ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                ScheduleDescription => 'every other Monday',
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
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { kingston => { url => 'http://example.org', nlpg => 'https://example.com/%s' } },
        waste => { kingston => 1 },
    },
}, sub {
    my $lwp = Test::MockModule->new('LWP::UserAgent');
    $lwp->mock('get', sub {
        my ($ua, $url) = @_;
        return $lwp->original('get')->(@_) unless $url =~ /example.com/;
        my ($uprn, $area) = (1000000002, "KINGSTON UPON THAMES");
        ($uprn, $area) = (1000000004, "SUTTON") if $url =~ /1000000004/;
        my $j = '{ "results": [ { "LPI": { "UPRN": ' . $uprn . ', "LOCAL_CUSTODIAN_CODE_DESCRIPTION": "' . $area . '" } } ] }';
        return HTTP::Response->new(200, 'OK', [], $j);
    });
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetEventsForObject', sub { [] });
    $echo->mock('FindPoints', sub { [
        { Description => '2 Example Street, Kingston, KT1 1AA', Id => '12345', SharedRef => { Value => { anyType => 1000000002 } } },
        { Description => '3 Example Street, Sutton, KT1 1AA', Id => '14345', SharedRef => { Value => { anyType => 1000000004 } } },
    ] });
    $echo->mock('GetPointAddress', sub {
        my ($self, $id) = @_;
        return {
            Id => $id,
            SharedRef => { Value => { anyType => $id == 14345 ? '1000000004' : '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.408688, Longitude => -0.304465 } },
            Description => '2/3 Example Street, Sutton, KT1 1AA',
        };
    });
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
    $echo->mock('GetTasks', sub { [] });

    subtest 'Look up of address not in correct borough' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'KT1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '14345' } });
        $mech->content_contains('No address on record');
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'KT1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        $mech->content_lacks('No address on record');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { kingston => { url => 'http://example.org' } },
        waste => { kingston => 1 },
        payment_gateway => { kingston => {
            cc_url => 'http://example.com',
            ggw_cost => 2000,
            ggw_new_bin_first_cost => 1500,
            ggw_new_bin_cost => 750,
            ggw_sacks_cost => 4100,
            hmac => '1234',
            hmac_id => '1234',
            scpID => '1234',
            company_name => 'rbk',
            form_name => 'rbk_user_form',
            staff_form_name => 'rbk_staff_form',
        } },
        bottomline => { kingston => {
        } },
    },
}, sub {
    my ($p) = $mech->create_problems_for_body(1, $body->id, 'Garden Subscription - New', {
        user_id => $user->id,
        category => 'Garden Subscription',
        whensent => \'current_timestamp',
    });
    $p->title('Garden Subscription - New');
    $p->update_extra_field({ name => 'property_id', value => 12345});
    $p->update;

    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetEventsForObject', sub { [] });
    $echo->mock('GetTasks', sub { [] });
    $echo->mock('FindPoints', sub { [
        { Description => '1 Example Street, Kingston, KT1 1AA', Id => '11345', SharedRef => { Value => { anyType => 1000000001 } } },
        { Description => '2 Example Street, Kingston, KT1 1AA', Id => '12345', SharedRef => { Value => { anyType => 1000000002 } } },
        { Description => '3 Example Street, Kingston, KT1 1AA', Id => '14345', SharedRef => { Value => { anyType => 1000000004 } } },
    ] });
    $echo->mock('GetPointAddress', sub {
        return {
            Id => 12345,
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.408688, Longitude => -0.304465 } },
            Description => '2 Example Street, Kingston, KT1 1AA',
        };
    });
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    my $sent_params;
    my $call_params;
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

    my $dd_sent_params = {};
    my $dd = Test::MockModule->new('Integrations::Bottomline');
    $dd->mock('call', sub {
        my ($self, $path, $data, $method) = @_;
        if ( $path =~ m#mandates/[^/]*/transaction# ) {
            $dd_sent_params->{'one_off_payment'} = $data;
            return {};
        } elsif ( $path =~ m#mandates/[^/]*/payment-plans# ) {
            $dd_sent_params->{'amend_plan'} = $data;
            return {};
        } elsif ( $method and $method eq 'DELETE' ) {
            $dd_sent_params->{cancel_plan} = {};
            return {};
        } elsif ( $path eq 'query/execute#getContactFromEmail' ) {
            return {
                rows => [ {
                  values => [ {
                     resultValues => [ {
                        value => {
                           '@type' => "ContactDTO",
                           id => 1,
                        }
                     } ]
                  } ]
                } ]
            }
        } elsif ( $path eq 'query/execute#planForMandateId' ) {
            $dd_sent_params->{'plan_for_mandate'} = $data;
            return {
                rows => [ {
                  values => [ {
                     resultValues => [ {
                        value => {
                           '@type' => "YearlyPaymentPlan",
                           id => 1369911,
                           mandateId => 4876123,
                           profileId => 4826,
                           status => "ACTIVE",
                           lastUpdated => "2018-09-01T08:05:22.646",
                           nextCollection => "2018-09-14T00:00:00.000",
                           extracted => 0,
                           created => "2018-07-06T14:32:13.950",
                           description => "A Direct Debit payment is due in respect of the above Direct Debit Instruction for £50.00 and will be collected on, or just after, the 15th of August 2018. Further payments of £50.00 will then be collected on, or just after, the 15th of each month until further notice.",
                           amountType => 0,
                           regularAmount => 50,
                           totalAmount => 0,
                           schedule => {
                              numberOfOccurrences => 0,
                              schedulePattern => "MONTHLY",
                              frequencyEnd => "NO_END",
                              startDate => "2018-08-15",
                              endDate => "0000-00-00"
                           },
                           everyNthMonth => 1,
                           monthDays => [ "DAY15" ]
                        }
                     } ]
                  } ]
                } ]
            }
        }
    });

    subtest 'Garden type lookup' => sub {
        set_fixed_time('2021-03-09T17:00:00Z');
        $mech->get_ok('/waste?type=garden');
        $mech->submit_form_ok({ with_fields => { postcode => 'KT1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        is $mech->uri->path, '/waste/12345', 'redirect as subscription';
    };

    subtest 'check subscription link present' => sub {
        set_fixed_time('2021-03-09T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_like(qr#Renewal</dt>\s*<dd[^>]*>30 March 2021#m);
        $mech->content_lacks('Subscribe to garden waste collection', 'Subscribe link not present for active sub');
        set_fixed_time('2021-04-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Subscribe to garden waste collection', 'Subscribe link present if expired at all');
        set_fixed_time('2021-05-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Subscribe to garden waste collection', 'Subscribe link present if expired');
    };

    subtest 'check overdue, soon due messages and modify link' => sub {
        $mech->log_in_ok($user->email);
        set_fixed_time('2021-04-05T17:00:00Z');
        $mech->get_ok('/waste/12345?1');
        $mech->content_contains('Subscribe to garden waste collection');
        $mech->content_lacks('Modify your garden waste subscription');
        $mech->content_lacks('Your subscription is now overdue', "No overdue link if after expired");
        set_fixed_time('2021-03-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Your subscription is soon due for renewal', "due soon link if within 30 days of expiry");
        $mech->content_lacks('Modify your garden waste subscription');
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/waste/12345', 'link redirect to bin list if modify in renewal period';
        set_fixed_time('2021-02-28T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Your subscription is soon due for renewal', "due soon link if 30 days before expiry");
        set_fixed_time('2021-02-27T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Your subscription is soon due for renewal', "no renewal notice if over 30 days before expiry");
        $mech->content_contains('Modify your garden waste subscription');
        $mech->log_out_ok;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);

    subtest 'Garden type lookup, no sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z');
        $mech->get_ok('/waste?type=garden');
        $mech->submit_form_ok({ with_fields => { postcode => 'KT1 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        is $mech->uri->path, '/waste/12345/garden', 'redirect as no subscription';
    };

    subtest 'check cannot cancel sub that does not exist' => sub {
        $mech->get_ok('/waste/12345/garden_cancel');
        is $mech->uri->path, '/waste/12345', 'cancel link redirect to bin list if no sub';
    };

    subtest 'check new sub bin limits' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes' } });
        $mech->content_contains('Please specify how many bins you already have');
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 0 } });
        $mech->content_contains('Existing bin count must be between 1 and 5');
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 7 } });
        $mech->content_contains('Existing bin count must be between 1 and 5');
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        my $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        is $mech->value('current_bins'), 0, "current bins is set to 0";
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 0,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('The total number of bins must be at least 1');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 2,
                bins_wanted => 7,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('The total number of bins cannot exceed 5');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 7,
                bins_wanted => 0,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 1 and 5');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 7,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 1 and 5');

        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 2 } });
        $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        $mech->content_like(qr#Total to pay now: £<span[^>]*>40.00#, "initial cost set correctly");
        is $mech->value('current_bins'), 2, "current bins is set to 2";
    };

    subtest 'check new sub credit card payment' => sub {
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
        $mech->content_contains('£20.00');
        $mech->content_contains('£15.00');
        $mech->content_contains('1 bin');
        $mech->submit_form_ok({ with_fields => { goto => 'details' } });
        $mech->content_contains('<span id="cost_pa">20.00');
        $mech->content_contains('<span id="cost_now">35.00');
        $mech->content_contains('<span id="cost_now_admin">15.00');
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
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, 1500, 'correct amount used';
        check_extra_data_pre_confirm($new_report);

        $mech->get('/waste/pay/xx/yyyyyyyyyyy');
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/pay_complete/$report_id/NOTATOKEN");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        check_extra_data_post_confirm($new_report);

        $mech->content_contains('We will aim to deliver your garden waste bin ');
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?35.00/;
    };

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
        $mech->content_contains('£20.00');
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';
        check_extra_data_pre_confirm($new_report, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        unlike $body, qr/Bins to be delivered/;
        like $body, qr/Total:.*?20.00/;
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
        $mech->content_contains('£20.00');
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';
        check_extra_data_pre_confirm($new_report, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be removed: 1/;
        like $body, qr/Total:.*?20.00/;
    };

    subtest 'check new sub direct debit payment' => sub {
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'direct_debit',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like( qr/ddregularamount[^>]*"20.00"/, 'payment amount correct');
        $mech->content_like( qr/ddfirstamount[^>]*"35.00"/, 'first payment amount correct');
        $mech->content_like( qr{rbk/rbk_user_form}, 'uses standard form');

        my ($token, $report_id) = ( $mech->content =~ m#reference:([^\^]*)\^report_id:(\d+)"# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->search( {
                id => $report_id,
                extra => { like => '%redirect_id,T18:'. $token . '%' }
        } )->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
        is $new_report->get_extra_metadata('ddsubmitted'), undef, "direct debit not marked as submitted";

        $mech->get_ok('/waste/12345');
        $mech->content_lacks('You have a pending garden subscription');
        $mech->content_contains('Subscribe to garden waste collection');

        $mech->get("/waste/dd_complete?customData=reference:$token^report_id:xxy");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/dd_complete?customData=reference:NOTATOKEN^report_id:$report_id");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get_ok("/waste/dd_complete?customData=reference:$token^report_id:$report_id&status=True&verificationapplied=False");
        $mech->content_contains('confirmation details once your Direct Debit');

        $mech->get_ok('/waste/12345');
        $mech->content_contains('You have a pending garden subscription');
        $mech->content_lacks('Subscribe to garden waste collection');

        $mech->email_count_is( 1, "email sent for direct debit sub");
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/waste subscription/s, 'direct debit email confirmation looks correct';
        like $body, qr/reference number is RBK-$report_id/, 'email has ID in it';
        $new_report->discard_changes;
        is $new_report->state, 'unconfirmed', 'report still not confirmed';
        is $new_report->get_extra_metadata('ddsubmitted'), 1, "direct debit marked as submitted";
        $new_report->delete;
    };

    subtest 'check new sub direct debit payment failed payment' => sub {
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'direct_debit',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like( qr/ddregularamount[^>]*"20.00"/, 'payment amount correct');
        $mech->content_like( qr/ddfirstamount[^>]*"35.00"/, 'first payment amount correct');
        $mech->content_like( qr{rbk/rbk_user_form}, 'uses standard form');

        my ($token, $report_id) = ( $mech->content =~ m#reference:([^\^]*)\^report_id:(\d+)"# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->search( {
                id => $report_id,
                extra => { like => '%redirect_id,T18:'. $token . '%' }
        } )->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - New', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
        is $new_report->get_extra_metadata('ddsubmitted'), undef, "direct debit not marked as submitted";

        $mech->get_ok('/waste/12345');
        $mech->content_lacks('You have a pending garden subscription');
        $mech->content_contains('Subscribe to garden waste collection');

        $mech->get("/waste/dd_complete?customData=reference:NOTATOKEN^report_id:$report_id&status=False&verificationapplied=True");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/dd_complete?customData=reference:$token^report_id:$report_id&status=False&verificationapplied=True");
        is $mech->res->code, 200, "got 200";
        $mech->content_contains('There was a problem with your attempt to pay by Direct Debit');
        $mech->content_contains('Retry to pay £35.00');

        # need to get the token again as it's unique per request
        ($token, $report_id) = ( $mech->content =~ m#reference:([^\^]*)\^report_id:(\d+)"# );
        $mech->get("/waste/dd_complete?customData=reference:$token^report_id:$report_id&stage=0&status=True&verificationapplied=True");
        is $mech->res->code, 200, "got 200";
        $mech->content_contains('There was a problem with your attempt to pay by Direct Debit');
        $mech->content_contains('Retry to pay £35.00');
        # need to get the token again as it's unique per request
        ($token, $report_id) = ( $mech->content =~ m#reference:([^\^]*)\^report_id:(\d+)"# );

        $mech->get_ok('/waste/12345');
        $mech->content_lacks('You have a pending garden subscription');
        $mech->content_contains('Subscribe to garden waste collection');

        $mech->email_count_is( 0, "no email sent for failed direct debit sub");

        $mech->get("/waste/dd_complete?customData=reference:$token^report_id:$report_id&&stage=6&status=True&verificationapplied=False");
        $mech->content_contains('confirmation details once your Direct Debit');
        $new_report->delete;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'check modify sub with bad details' => sub {
        set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/auth', 'have to be logged in to modify subscription';
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 2, bins_wanted => 3 } });
        $mech->content_contains('3 bins');
        $mech->content_contains('60.00');
        $mech->content_contains('35.00');
    };
    subtest 'check modify sub credit card payment' => sub {
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('2 bins');
        $mech->content_contains('40.00');
        $mech->content_contains('35.00');
        $mech->submit_form_ok({ with_fields => { goto => 'alter' } });
        $mech->content_contains('<span id="cost_per_year">40.00');
        $mech->content_contains('<span id="cost_now_admin">15.00');
        $mech->content_contains('<span id="pro_rata_cost">35.00');
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, 1500, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Amend', quantity => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 2/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?35.00/;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);
    subtest 'check modify sub credit card payment reducing bin count' => sub {
        set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
        $sent_params = undef;

        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 2, bins_wanted => 1 } });
        $mech->content_contains('20.00');
        $mech->content_lacks('Continue to payment');
        $mech->content_contains('Confirm changes');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $sent_params, undef, "no one off payment if reducing bin count";
        check_extra_data_pre_confirm($new_report, type => 'Amend', state => 'confirmed', action => 2);
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_field_value('payment'), '0', 'no payment if removing bins';
        is $new_report->get_extra_field_value('pro_rata'), '', 'no pro rata payment if removing bins';

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be removed: 1/;
        unlike $body, qr/Total:/;
    };
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'renew credit card sub' => sub {
        $mech->log_out_ok();
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 0,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('Value must be between 1 and 5');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('1 bin');
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { goto => 'intro' } });
        $mech->content_contains('<span id="cost_pa">20.00');
        $mech->content_contains('<span id="cost_now">20.00');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
        } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Thank you for renewing/;
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Total:.*?20.00/;
    };

    subtest 'renew credit card sub with an extra bin' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 7,
            payment_method => 'credit_card',
        } });
        $mech->content_contains('The total number of bins cannot exceed 5');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 2,
            payment_method => 'credit_card',
            name => 'New McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('40.00');
        $mech->content_contains('15.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 4000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, 1500, 'correct amount used';
        is $call_params->{'scpbase:billing'}{'scpbase:cardHolderDetails'}{'scpbase:cardHolderName'}, 'New McTest', 'Correct name';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', quantity => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 2/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?55.00/;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);
    subtest 'renew credit card sub with one less bin' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        my $form = $mech->form_with_fields( qw( current_bins payment_method ) );
        ok $form, 'found form';
        is $mech->value('current_bins'), 2, "correct current bin count";
        $mech->submit_form_ok({ with_fields => {
            current_bins => 2,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', action => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be removed: 1/;
        like $body, qr/Total:.*?20.00/;
    };
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    remove_test_subs( $p->id );
    $p->update_extra_field({ name => 'payment_method', value => 'direct_debit' });
    $p->set_extra_metadata('dd_mandate_id', '100');
    $p->set_extra_metadata('dd_contact_id', '101');
    $p->update;

    subtest 'cancel direct debit sub' => sub {
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->state, 'unconfirmed', 'report confirmed';
        is $p->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment type on report';

        is_deeply $dd_sent_params->{cancel_plan}, {}, "correct direct debit cancellation params sent";

        $mech->get_ok('/waste/12345');
        $mech->content_contains('Cancellation in progress');
    };

    remove_test_subs( $p->id );

    $p->update_extra_field({ name => 'payment_method', value => 'credit_card' });
    $p->update;

    subtest 'renew credit card sub after end of sub' => sub {
        set_fixed_time('2021-04-01T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('subscription is now overdue');
        $mech->content_lacks('Renew your garden waste subscription', 'renew link still on expired subs');
    };

    remove_test_subs( $p->id );
    $p->update_extra_field({ name => 'payment_method', value => 'credit_card' });
    $p->update;

    subtest 'renew credit card sub with direct debit' => sub {
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'direct_debit',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        $mech->content_like( qr/ddregularamount[^>]*"20.00"/, 'payment amount correct');
        $mech->content_lacks( "ddfirstamount", "no different first payment");
        $mech->content_like( qr{rbk/rbk_user_form}, 'uses standard form');

        my ($token, $report_id) = ( $mech->content =~ m#reference:([^\^]*)\^report_id:(\d+)"# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->search( {
                id => $report_id,
                extra => { like => '%redirect_id,T18:'. $token . '%' }
        } )->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->get_extra_field_value('Request_Type'), 2, 'correct subscription type';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Subscription_Details_Containers'), 26, 'correct bin type';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Container'), '', 'no container request bin type';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Containers'), '', 'no container request count';
        is $new_report->state, 'unconfirmed', 'report not confirmed';

        $mech->get_ok('/waste/12345');
        $mech->content_lacks('You have a pending garden subscription');
        $mech->content_lacks('Subscribe to garden waste collection');

        $mech->get("/waste/dd_complete?customData=reference:$token^report_id:xxy");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/dd_complete?customData=reference:NOTATOKEN^report_id:$report_id");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/dd_complete?customData=reference:$token^report_id:$report_id");
        $mech->content_contains('confirmation details once your Direct Debit');

        $mech->get_ok('/waste/12345');
        $mech->content_contains('You have a pending garden subscription');
        $mech->content_lacks('Subscribe to garden waste collection');

        $new_report->discard_changes;
        is $new_report->state, 'unconfirmed', 'report still not confirmed';

        # Delete report otherwise next test thinks we have a DD subscription (which we do now)
        $new_report->delete;
    };

    remove_test_subs( $p->id );

    subtest 'renew credit card sub after end of sub increasing bins' => sub {
        set_fixed_time('2021-04-01T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('subscription is now overdue');
        $mech->content_lacks('Renew your garden waste subscription', 'renew link still on expired subs');
    };

    subtest 'cancel credit card sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Subscription_End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Container'), 26, 'correct container request bin type';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Containers'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        unlike $body, qr/Number of bin subscriptions/;
        unlike $body, qr/Bins to be delivered/;
    };

    my $report = FixMyStreet::DB->resultset("Problem")->search({
        category => 'Garden Subscription',
        title => 'Garden Subscription - New',
        extra => { like => '%property_id,T5:value,I5:12345%' }
    },
    {
        order_by => { -desc => 'id' }
    })->first;

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_only_refuse_sacks);

    subtest 'sacks, subscribing to a bin' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin' } });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
            current_bins => 0,
            bins_wanted => 1,
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->content_contains('£15.00');
        $mech->content_contains('1 bin');
        $mech->submit_form_ok({ with_fields => { goto => 'details' } });
        $mech->content_contains('<span id="cost_pa">20.00');
        $mech->content_contains('<span id="cost_now">35.00');
        $mech->content_contains('<span id="cost_now_admin">15.00');
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
            current_bins => 0,
            bins_wanted => 1,
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, 1500, 'correct amount used';
        check_extra_data_pre_confirm($new_report);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        check_extra_data_post_confirm($new_report);

        $mech->content_contains('We will aim to deliver your garden waste bin ');
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?35.00/;
    };

    subtest 'sacks, subscribing' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->content_like(qr#Total per year: £<span[^>]*>41.00#, "initial cost correct");
        $mech->content_lacks('"cheque"');
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£41.00');
        $mech->content_contains('Sacks');
        $mech->submit_form_ok({ with_fields => { goto => 'sacks_details' } });
        $mech->content_contains('<span id="cost_pa">41.00');
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });

        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 4100, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';
        check_extra_data_pre_confirm($new_report, bin_type => 28);

        $mech->get('/waste/pay/xx/yyyyyyyyyyy');
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/pay_complete/$report_id/NOTATOKEN");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        check_extra_data_post_confirm($new_report);

        $mech->content_contains('We will aim to deliver your garden waste sacks ');
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Garden waste sack collection: 1 roll/;
        unlike $body, qr/Number of bin subscriptions/;
        like $body, qr/Total:.*?41.00/;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_bin_with_refuse_sacks);

    subtest 'refuse sacks, garden bin, still asks for choice' => sub {
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('1 bin');
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0);
    };

    subtest 'refuse sacks, garden bin, can modify' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Modify your garden waste subscription');
        $mech->content_lacks('Order more garden sacks');
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->content_lacks('<span id="pro_rata_cost">41.00');
        $mech->content_contains('current_bins');
        $mech->content_contains('bins_wanted');
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2, name => 'Test McTest' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, 1500, 'no admin fee';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, type => 'Amend', quantity => 2);
    };

    subtest 'refuse sacks, garden bin, cancelling' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Subscription_End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Container'), 26, 'correct container request bin type';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Containers'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_with_sacks);

    subtest 'sacks, renewing' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->submit_form_ok({ with_fields => {
            name => 'Test McTest',
            email => 'test@example.net',
            payment_method => 'credit_card',
        } });
        $mech->content_contains('Sacks');
        $mech->content_contains('41.00');
        $mech->submit_form_ok({ with_fields => { goto => 'sacks_choice' } });
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->content_contains('<span id="cost_pa">41.00');
        $mech->content_contains('<span id="cost_now">41.00');
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
        } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 4100, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', bin_type => 28);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    subtest 'sacks, cannot modify, but can buy more' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Modify your garden waste subscription');
        $mech->content_contains('Order more garden sacks');
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->content_contains('<span id="pro_rata_cost">41.00');
        $mech->content_lacks('current_bins');
        $mech->content_lacks('bins_wanted');
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 4100, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'no admin fee';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Amend', quantity => 1, bin_type => 28);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

    };

    subtest 'sacks, cancelling' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Subscription_End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Container'), '', 'correct container request bin type';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Containers'), '', 'correct container request action';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Quantity'), '', 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'check staff renewal' => sub {
        foreach ({ email => 'a_user@example.net' }, { phone => '07700900002' }) {
            $mech->log_out_ok;
            $mech->log_in_ok($staff_user->email);
            $mech->get_ok('/waste/12345/garden_renew');
            $mech->submit_form_ok({ with_fields => {
                name => 'a user',
                %$_, # email or phone,
                current_bins => 1,
                bins_wanted => 1,
                payment_method => 'credit_card',
            }});
            $mech->content_contains('20.00');

            $mech->submit_form_ok({ with_fields => { tandc => 1 } });
            is $call_params->{'scpbase:panEntryMethod'}, 'CNP', 'Correct cardholder-not-present flag';
            is $call_params->{'scpbase:billing'}{'scpbase:cardHolderDetails'}{'scpbase:cardHolderName'}, 'a user', 'Correct name';
            if ($_->{email}) {
                is $call_params->{'scpbase:billing'}{'scpbase:cardHolderDetails'}{'scpbase:contact'}{'scpbase:email'}, $_->{email}, 'Correct email';
            } else {
                is $call_params->{'scpbase:billing'}{'scpbase:cardHolderDetails'}{'scpbase:contact'}, undef, 'No email section';
            }
            is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
            is $sent_params->{items}[1]{amount}, undef, 'correct amount used';

            my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            check_extra_data_pre_confirm($report, type => 'Renew', new_bins => 0);

            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

            check_extra_data_post_confirm($report);
            $report->delete; # Otherwise next test sees this as latest
        }
    };

    subtest 'check staff renewal with direct debit' => sub {
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            name => 'a user',
            email => 'a_user@example.net',
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'direct_debit',
        }});
        $mech->content_contains('20.00');

        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        $mech->content_like( qr/ddregularamount[^>]*"20.00"/, 'payment amount correct');
        $mech->content_like( qr{rbk/rbk_staff_form}, 'uses staff form');

        my ($token, $report_id) = ( $mech->content =~ m#reference:([^\^]*)\^report_id:(\d+)"# );
        my $new_report = FixMyStreet::DB->resultset('Problem')->search( {
                id => $report_id,
                extra => { like => '%redirect_id,T18:'. $token . '%' }
        } )->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Renew', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
        is $new_report->get_extra_metadata('ddsubmitted'), undef, "direct debit not marked as submitted";

        $mech->get_ok('/waste/12345');
        $mech->content_lacks('You have a pending garden subscription');

        $mech->get_ok("/waste/dd_complete?customData=reference:$token^report_id:$report_id");
        $mech->content_contains('confirmation details once your Direct Debit');

        $mech->get_ok('/waste/12345');
        $mech->content_contains('You have a pending garden subscription');

        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/waste subscription/s, 'direct debit email confirmation looks correct';
        like $body, qr/reference number is RBK-$report_id/, 'email has ID in it';
        $new_report->discard_changes;
        is $new_report->state, 'unconfirmed', 'report still not confirmed';
        is $new_report->get_extra_metadata('ddsubmitted'), 1, "direct debit marked as submitted";
        $new_report->delete;
    };

    subtest 'check modify sub staff' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 2,
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('40.00');
        $mech->content_contains('15.00');
        $mech->content_contains('35.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $call_params->{'scpbase:panEntryMethod'}, 'CNP', 'Correct cardholder-not-present flag';

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($report, type => 'Amend', quantity => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        check_extra_data_post_confirm($report);
        is $report->name, 'Test McTest', 'non staff user name';
        is $report->user->email, 'test@example.net', 'non staff email';

        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        $report->delete; # Otherwise next test sees this as latest
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);
    subtest 'check modify sub staff reducing bin count' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');

        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 2,
            bins_wanted => 1,
            name => 'A user',
            email => 'test@example.net',
        } });
        $mech->content_contains('20.00');
        $mech->content_lacks('Continue to payment');
        $mech->content_contains('Confirm changes');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->content_lacks($staff_user->email);

        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number\s*<br><strong>.*?(\d+)<#);
        my $new_report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_field_value('Subscription_Details_Quantity'), 1, 'correct bin count';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Containers'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Bin_Delivery_Detail_Quantity'), 1, 'correct container request count';
        is $new_report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $new_report->get_extra_metadata('contributed_as'), 'another_user';
        is $new_report->get_extra_field_value('payment'), '0', 'no payment if removing bins';
        is $new_report->get_extra_field_value('pro_rata'), '', 'no pro rata payment if removing bins';
    };
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'cancel staff sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Subscription_End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $new_report->get_extra_metadata('contributed_as'), 'anonymous_user';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);
    subtest 'staff create new subscription' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->content_lacks('password', 'no password field');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->content_contains('1 bin');
        # external redirects make Test::WWW::Mechanize unhappy so clone
        # the mech for the redirect
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        is $call_params->{'scpbase:panEntryMethod'}, 'CNP', 'Correct cardholder-not-present flag';

        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($report);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        check_extra_data_post_confirm($report);
        is $report->name, 'Test McTest', 'non staff user name';
        is $report->user->email, 'test@example.net', 'non staff email';

        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        is $report->user->email, 'test@example.net';
        is $report->get_extra_metadata('contributed_by'), $staff_user->id;
        $report->delete; # Otherwise next test sees this as latest
    };

    subtest 'staff create new subscription with a cheque' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 1,
            payment_method => 'cheque',
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains("Cheque reference field is required");
        $mech->submit_form_ok({ with_fields => {
            cheque_reference => 'Cheque123',
        } });
        $mech->content_contains('£20.00');
        $mech->content_contains('1 bin');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my ($report_id) = $mech->content =~ m#RBK-(\d+)#;
        my $report = FixMyStreet::DB->resultset('Problem')->search( { id => $report_id } )->first;

        check_extra_data_pre_confirm($report, payment_method => 'cheque', state => 'confirmed');
        is $report->get_extra_field_value('LastPayMethod'), 4, 'correct echo payment method field';
        is $report->get_extra_metadata('chequeReference'), 'Cheque123', 'cheque reference saved';
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        $report->delete; # Otherwise next test sees this as latest
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    remove_test_subs( $p->id );

    $p->category('Garden Subscription');
    $p->title('Garden Subscription - New');
    $p->update_extra_field({ name => 'payment_method', value => 'direct_debit' });
    $p->set_extra_metadata('payerReference', 'RBK-' . $p->id . '1000000002');
    $p->set_extra_metadata('dd_mandate_id', '100');
    $p->set_extra_metadata('dd_contact_id', '101');
    $p->update;

    subtest 'check modify sub direct debit payment' => sub {
        set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('40.00');
        $mech->content_contains('15.00');
        $mech->content_contains('35.00');
        $mech->content_contains('Amend Direct Debit');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Garden Subscription', 'correct category on report';
        is $new_report->title, 'Garden Subscription - Amend', 'correct title on report';
        is $new_report->get_extra_field_value('payment_method'), 'direct_debit', 'correct payment method on report';
        is $new_report->state, 'unconfirmed', 'report not confirmed';
        is $new_report->get_extra_field_value('payment'), '4000', 'payment correctly set to future value';
        is $new_report->get_extra_field_value('pro_rata'), '2000', 'pro rata payment correctly set';
        is $new_report->get_extra_field_value('admin_fee'), '1500', 'adming fee payment correctly set';

        my $ad_hoc_payment_date = '2021-01-15T17:00:00';

        is_deeply $dd_sent_params->{one_off_payment}, {
            comments => $new_report->id,
            amount => '35.00',
            dueDate => $ad_hoc_payment_date,
            paymentType => 'DEBIT',
        }, "correct direct debit ad hoc payment params sent";
        is $dd_sent_params->{amend_plan}->{regularAmount}, '40.00', "correct direct debit amendment params sent";
    };

    $dd_sent_params = {};

    # remove all reports
    remove_test_subs( 0 );

    subtest 'modify sub with no existing waste sub - credit card payment' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/auth', 'have to be logged in to modify subscription';
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('40.00');
        $mech->content_contains('15.00');
        $mech->content_contains('35.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, 1500, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Amend', quantity => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    remove_test_subs( 0 );

    subtest 'cancel credit card sub with no record in waste' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('Subscription_End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    remove_test_subs( 0 );

    subtest 'check staff renewal with no existing sub' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            name => 'a user',
            email => 'a_user@example.net',
            payment_method => 'credit_card',
            current_bins => 1,
            bins_wanted => 1,
        }});

        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    subtest 'check CSV export' => sub {
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            name => 'a user 2',
            email => 'a_user_2@example.net',
            payment_method => 'credit_card',
            current_bins => 1,
            bins_wanted => 2,
        }});
        $mech->content_contains('40.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, type => 'Renew', quantity => 2);

        $mech->get_ok('/dashboard?export=1');
        $mech->content_lacks("Garden Subscription\n\n");
        $mech->content_contains('"a user"');
        $mech->content_contains(1000000002);
        $mech->content_contains('a_user@example.net');
        $mech->content_contains('credit_card,54321,2000,,0,26,1,1'); # Method/ref/fee/fee/fee/bin/current/sub
        $mech->content_contains('"a user 2"');
        $mech->content_contains('a_user_2@example.net');
        $mech->content_contains('unconfirmed');
        $mech->content_contains('4000,,1500,26,1,2'); # Fee/fee/fee/bin/current/sub
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

sub remove_test_subs {
    my $base_id = shift;

    FixMyStreet::DB->resultset('Problem')->search({
                id => { '<>' => $base_id },
                category => [ 'Garden Subscription', 'Cancel Garden Subscription' ],
    })->delete;
}

sub check_extra_data_pre_confirm {
    my $report = shift;
    my %params = (
        type => 'New',
        state => 'unconfirmed',
        quantity => 1,
        new_bins => 1,
        action => 1,
        bin_type => 26,
        payment_method => 'credit_card',
        @_
    );
    $report->discard_changes;
    is $report->category, 'Garden Subscription', 'correct category on report';
    is $report->title, "Garden Subscription - $params{type}", 'correct title on report';
    is $report->get_extra_field_value('payment_method'), $params{payment_method}, 'correct payment method on report';
    is $report->get_extra_field_value('Subscription_Details_Quantity'), $params{quantity}, 'correct bin count';
    is $report->get_extra_field_value('Subscription_Details_Containers'), $params{bin_type}, 'correct bin type';
    if ($params{new_bins}) {
        is $report->get_extra_field_value('Bin_Delivery_Detail_Container'), $params{bin_type}, 'correct container request bin type';
        is $report->get_extra_field_value('Bin_Delivery_Detail_Containers'), $params{action}, 'correct container request action';
        is $report->get_extra_field_value('Bin_Delivery_Detail_Quantity'), $params{new_bins}, 'correct container request count';
    }
    is $report->state, $params{state}, 'report state correct';
    if ($params{state} eq 'unconfirmed') {
        is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
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
