use File::Temp 'tempdir';
use JSON::MaybeXS;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2480, 'Kingston upon Thames Council', { cobrand => 'kingston' });
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
    { code => 'Paid_Container_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Paid_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'current_containers', required => 1, automated => 'hidden_field' },
    { code => 'new_containers', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'pro_rata', required => 0, automated => 'hidden_field' },
    { code => 'admin_fee', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Amend Garden Subscription', email => 'garden@example.com'},
    { code => 'Additional_Container_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Additional_Collection_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Container_Ordered_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Ordered_Type', required => 1, automated => 'hidden_field' },
    { code => 'current_containers', required => 1, automated => 'hidden_field' },
    { code => 'new_containers', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'pro_rata', required => 0, automated => 'hidden_field' },
    { code => 'admin_fee', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Cancel Garden Subscription', email => 'garden_cancel@example.com'},
    { code => 'End_Date', required => 1, automated => 'hidden_field' },
);

create_contact({ category => 'Request new container', email => '3129@example.com' },
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 1, automated => 'hidden_field' },
    { code => 'Reason', required => 1, automated => 'hidden_field' },
);

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

sub garden_waste_no_bins {
    return [ {
        Id => 1001,
        ServiceId => 980,
        ServiceName => 'Food waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 400,
            TaskTypeId => 4389,
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
        ServiceId => 979,
        ServiceName => 'Garden waste collection',
        ServiceTasks => ''
    } ];
}

sub garden_waste_only_refuse_sacks {
    return [ {
        Id => 1001,
        ServiceId => 967,
        ServiceName => 'Refuse collection',
        ServiceTasks => { ServiceTask => {
            Id => 400,
            TaskTypeId => 4395,
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
        ServiceId => 979,
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

    my $bin_type_id = $type eq 'sack' ? 1928 : 1915;

    return [ {
        Id => 1002,
        ServiceId => 979,
        ServiceName => 'Garden waste collection',
        ServiceTasks => { ServiceTask => {
            Id => 405,
            TaskTypeId => 4410,
            ServiceTaskLines => { ServiceTaskLine => [ {
                ScheduledAssetQuantity => $bin_count,
                AssetTypeId => $bin_type_id,
                StartDate => { DateTime => '2020-03-30T00:00:00Z' },
                EndDate => { DateTime => '2021-03-30T00:00:00Z' },
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

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    COBRAND_FEATURES => {
        echo => { kingston => { url => 'http://example.org' } },
        waste => { kingston => 1 },
        waste_features => { kingston => { dd_disabled => 1 } },
        payment_gateway => { kingston => {
            cc_url => 'http://example.com',
            ggw_cost => [
                {
                    start_date => '2020-01-01 00:00',
                    cost => 2000,
                },
                {
                    start_date => '2023-01-06 00:00',
                    cost => 2500,
                }
            ],
            ggw_cost_renewal => [
                {
                    start_date => '2020-01-01 00:00',
                    cost => 2000,
                }
            ],
            ggw_new_bin_first_cost => 1500,
            ggw_new_bin_cost => 750,
            ggw_sacks_cost => [
                {
                    start_date => '2020-01-01 00:00',
                    cost => 4100,
                },
                {
                    start_date => '2023-01-06 00:00',
                    cost => 4300,
                },
            ],
            ggw_sacks_cost_renewal => [
                {
                    start_date => '2020-01-01 00:00',
                    cost => 4100,
                }
            ],
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
        send_state => 'sent',
    });
    $p->title('Garden Subscription - New');
    $p->update_extra_field({ name => 'property_id', value => '12345'});
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
            Id => '12345',
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.408688, Longitude => -0.304465 } },
            Description => '2 Example Street, Kingston, KT1 1AA',
        };
    });
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
    mock_CancelReservedSlotsForEvent($echo);

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
        $mech->content_lacks('Change your garden waste subscription');
        $mech->content_lacks('Your subscription is now overdue', "No overdue link if after expired");
        set_fixed_time('2021-03-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Your subscription is soon due for renewal', "due soon link if within 30 days of expiry");
        $mech->content_lacks('Change your garden waste subscription');
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/waste/12345', 'link redirect to bin list if modify in renewal period';
        set_fixed_time('2021-02-28T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Your subscription is soon due for renewal', "due soon link if 30 days before expiry");
        set_fixed_time('2021-02-27T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Your subscription is soon due for renewal', "no renewal notice if over 30 days before expiry");
        $mech->content_contains('Change your garden waste subscription');
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
        my $form = $mech->form_with_fields( qw(current_bins bins_wanted) );
        ok $form, "form found";
        is $mech->value('current_bins'), 0, "current bins is set to 0";
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 0,
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('The total number of bins must be at least 1');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 2,
                bins_wanted => 7,
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('The total number of bins cannot exceed 5');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 7,
                bins_wanted => 0,
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 1 and 5');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 7,
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 1 and 5');

        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 2 } });
        $form = $mech->form_with_fields( qw(current_bins bins_wanted) );
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
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

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
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

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
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£20.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';
        check_extra_data_pre_confirm($new_report, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);
        check_removal_data_and_emails($mech, $new_report);
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

        check_amend_extra_data_pre_confirm($new_report);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of additional bin subscriptions: 1/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?35.00/;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'renew credit card sub' => sub {
        $mech->log_out_ok();
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 0,
            bins_wanted => 0,
        } });
        $mech->content_contains('Value must be between 1 and 5');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
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
        } });
        $mech->content_contains('The total number of bins cannot exceed 5');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 2,
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
        my $form = $mech->form_with_fields( qw( current_bins ) );
        ok $form, 'found form';
        is $mech->value('current_bins'), 2, "correct current bin count";
        $mech->submit_form_ok({ with_fields => {
            current_bins => 2,
            bins_wanted => 1,
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('20.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 2000, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);
        check_removal_data_and_emails($mech, $new_report);
    };
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    remove_test_subs( $p->id );

    subtest 'renew credit card sub after end of sub' => sub {
        set_fixed_time('2021-04-01T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('subscription is now overdue');
        $mech->content_lacks('Renew your garden waste subscription', 'renew link still on expired subs');
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
        $mech->submit_form_ok({ with_fields => { continue => 1 } });
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '09/03/2021', 'cancel date set to current date';
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
        extra => { '@>' => encode_json({ "_fields" => [ { name => "property_id", value => '12345' } ] }) }
    },
    {
    })->order_by('-id')->first;

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_only_refuse_sacks);

    subtest 'sacks, subscribing to a bin' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin' } });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_like(qr#Total to pay now: £<span[^>]*>0.00#, "initial cost set to zero");
        $mech->submit_form_ok({ with_fields => {
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
            current_bins => 0,
            bins_wanted => 1,
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

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
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£41.00');
        $mech->content_contains('1 sack subscription');
        $mech->submit_form_ok({ with_fields => { goto => 'sacks_details' } });
        $mech->content_contains('<span id="cost_pa">41.00');
        $mech->submit_form_ok({ with_fields => {
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('£41.00');
        $mech->content_lacks('£15.00');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 4100, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';
        check_extra_data_pre_confirm($new_report, bin_type => 1928, quantity => 11, new_bins => 11);

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
        $mech->content_contains('Change your garden waste subscription');
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
        check_amend_extra_data_pre_confirm($new_report);
    };

    subtest 'refuse sacks, garden bin, cancelling' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { continue => 1 } });
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '09/03/2021', 'cancel date set to current date';
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
        } });
        $mech->content_contains('1 sack subscription');
        $mech->content_contains('41.00');
        $mech->submit_form_ok({ with_fields => { goto => 'sacks_choice' } });
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->content_contains('<span id="cost_pa">41.00');
        $mech->content_contains('<span id="cost_now">41.00');
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 4100, 'correct amount used';
        is $sent_params->{items}[1]{amount}, undef, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', bin_type => 1928, quantity => 11, new_bins => 11);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    subtest 'sacks, cannot modify, but can buy more' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Change your garden waste subscription');
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

        check_extra_data_pre_confirm($new_report, type => 'Amend', quantity => 1, bin_type => 1928, quantity => 11, new_bins => 11);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

    };

    subtest 'sacks, cancelling' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { continue => 1 } });
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '09/03/2021', 'cancel date set to current date';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'check staff renewal' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            name => 'a user',
            email => 'a_user@example.net',
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
        }});
        $mech->content_contains('20.00');

        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->submit_form_ok({ with_fields => { payenet_code => 54321 } });

        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number\s*<br><strong>RBK-(\d+)<#);
        ok $id, "confirmation page contains id";
        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        check_extra_data_pre_confirm($report, type => 'Renew', new_bins => 0, payment_method => 'csc', state => 'confirmed');
        check_extra_data_post_confirm($report);
        $report->delete; # Otherwise next test sees this as latest
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
        $mech->submit_form_ok({ with_fields => { payenet_code => 54321 } });

        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number\s*<br><strong>RBK-(\d+)<#);
        ok $id, "confirmation page contains id";
        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        check_amend_extra_data_pre_confirm($report, payment_method => 'csc', state => 'confirmed');

        check_extra_data_post_confirm($report);
        is $report->name, 'Test McTest', 'non staff user name';
        is $report->user->email, 'test@example.net', 'non staff email';

        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        $report->delete; # Otherwise next test sees this as latest
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'cancel staff sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { continue => 1 } });
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        my $new_report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '09/03/2021', 'cancel date set to current date';
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
        $mech->content_lacks('name="password', 'no password field');
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
        $mech->submit_form_ok({ with_fields => { payenet_code => 54321 } });

        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number\s*<br><strong>RBK-(\d+)<#);
        ok $id, "confirmation page contains id";
        my $report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        check_extra_data_pre_confirm($report, payment_method => 'csc', state => 'confirmed');
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
        $mech->content_contains("Payment reference field is required");
        $mech->submit_form_ok({ with_fields => {
            cheque_reference => 'Cheque123',
        } });
        $mech->content_contains('£20.00');
        $mech->content_contains('1 bin');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my ($report_id) = $mech->content =~ m#RBK-(\d+)#;
        my $report = FixMyStreet::DB->resultset('Problem')->search( { id => $report_id } )->first;

        check_extra_data_pre_confirm($report, payment_method => 'cheque', state => 'confirmed');
        is $report->get_extra_metadata('chequeReference'), 'Cheque123', 'cheque reference saved';
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        $report->delete; # Otherwise next test sees this as latest
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

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

        check_amend_extra_data_pre_confirm($new_report);

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
        $mech->submit_form_ok({ with_fields => { continue => 1 } });
        $mech->submit_form_ok({ with_fields => { confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { user_id => $user->id },
        )->order_by('-id')->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '09/03/2021', 'cancel date set to current date';
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
        $mech->submit_form_ok({ with_fields => { payenet_code => 54321 } });

        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number\s*<br><strong>RBK-(\d+)<#);
        ok $id, "confirmation page contains id";
        my $new_report = FixMyStreet::DB->resultset("Problem")->find({ id => $id });

        check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0, payment_method => 'csc', state => 'confirmed');
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    subtest 'check CSV export' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            name => 'a user 2',
            email => 'a_user_2@example.net',
            current_bins => 1,
            bins_wanted => 2,
        }});
        $mech->content_contains('40.00');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', quantity => 2);

        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_lacks("Garden Subscription\n\n");
        $mech->content_contains('"a user"');
        $mech->content_contains(1000000002);
        $mech->content_contains('a_user@example.net');
        $mech->content_contains('csc,54321,2000,,0,1915,1,1'); # Method/ref/fee/fee/fee/bin/current/sub
        $mech->content_contains('"a user 2"');
        $mech->content_contains('a_user_2@example.net');
        $mech->content_contains('unconfirmed');
        $mech->content_contains('4000,,1500,1915,1,2'); # Fee/fee/fee/bin/current/sub
    };

    subtest 'check CSV pregeneration' => sub {
        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_lacks("Garden Subscription\n\n");
        $mech->content_contains('"a user"');
        $mech->content_contains(1000000002);
        $mech->content_contains('a_user@example.net');
        $mech->content_contains('csc,54321,2000,,0,1915,1,1'); # Method/ref/fee/fee/fee/bin/current/sub
        $mech->content_contains('"a user 2"');
        $mech->content_contains('a_user_2@example.net');
        $mech->content_contains('unconfirmed');
        $mech->content_contains('4000,,1500,1915,1,2'); # Fee/fee/fee/bin/current/sub
    };

    subtest 'check new sub price changes at fixed time' => sub {
        set_fixed_time('2023-01-05T23:59:59Z');
        $mech->log_out_ok;

        $mech->get_ok('/waste/12345/garden');
        $mech->content_contains("It costs\n£20.00\nfor a 12-month");
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_contains('<span class="cost-pa">£20.00 per bin per year</span>');

        set_fixed_time('2023-01-06T00:00:00Z'); # New pricing should be in effect

        $mech->get_ok('/waste/12345/garden');
        $mech->content_contains("It costs\n£25.00\nfor a 12-month");
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->content_contains('<span class="cost-pa">£25.00 per bin per year</span>');

        restore_time;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_only_refuse_sacks);

    subtest 'sacks, subscription price changes at fixed time' => sub {
        set_fixed_time('2023-01-05T23:59:59Z');
        $mech->log_out_ok;

        $mech->get_ok('/waste/12345/garden');
        $mech->content_contains('A roll of 10 garden waste sacks costs £41.00');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->content_like(qr#Total per year: £<span[^>]*>41.00#, "initial cost correct");

        set_fixed_time('2023-01-06T00:00:00Z'); # New pricing should be in effect

        $mech->get_ok('/waste/12345/garden');
        $mech->content_contains('A roll of 10 garden waste sacks costs £43.00');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->content_like(qr#Total per year: £<span[^>]*>43.00#, "new cost correct");

        restore_time;
    };
};

# Test renewing with different end date subscriptions

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { kingston => { url => 'http://example.org' } },
        waste => { kingston => 1 },
        waste_features => { kingston => { dd_disabled => 1 } },
        payment_gateway => { kingston => {
            ggw_cost => [ { start_date => '2020-01-01 00:00', cost => 2000 } ],
            ggw_cost_renewal => [
                { start_date => '2020-01-01 00:00', cost => 2000 },
                { start_date => '2021-03-31 00:00', cost => 2600 }
            ],
            ggw_new_bin_first_cost => 1500,
            ggw_new_bin_cost => 750,
            ggw_sacks_cost => [ { start_date => '2020-01-01 00:00', cost => 4100 } ],
            ggw_sacks_cost_renewal => [
                { start_date => '2020-01-01 00:00', cost => 4100 },
                { start_date => '2021-03-31 00:00', cost => 4600 }
            ],
        } },
    },
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetEventsForObject', sub { [] });
    $echo->mock('GetTasks', sub { [] });
    $echo->mock('GetPointAddress', sub {
        return {
            Id => '12345',
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.408688, Longitude => -0.304465 } },
            Description => '2 Example Street, Kingston, KT1 1AA',
        };
    });
    mock_CancelReservedSlotsForEvent($echo);
    set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection

    for my $test (
        { end_date => '2021-03-30', price => 20, sack_price => 41 },
        { end_date => '2021-03-31', price => 26, sack_price => 46 },
        { end_date => '2021-04-01', price => 26, sack_price => 46 },
        ) {
        subtest "renew bin with end date $test->{end_date}" => sub {
            $echo->mock('GetServiceUnitsForObject', sub {
                my $units = garden_waste_one_bin();
                $units->[1]{ServiceTasks}{ServiceTask}{ServiceTaskSchedules}{ServiceTaskSchedule}[0]{EndDate}{DateTime} = $test->{end_date} . 'T00:00:00Z';
                return $units;
            });

            $mech->get_ok('/waste/12345/garden_renew');
            $mech->content_contains('<span id="cost_pa">' . $test->{price} . '.00');
            $mech->content_contains('<span id="cost_now">' . $test->{price} . '.00');
            $mech->submit_form_ok({ with_fields => {
                current_bins => 1,
                bins_wanted => 1,
                name => 'Test McTest',
                email => 'test@example.net',
            } });
            $mech->content_contains('1 bin');
            $mech->content_contains($test->{price} . '.00');
        };
        subtest "renew sack with end date $test->{end_date}" => sub {
            $echo->mock('GetServiceUnitsForObject', sub {
                my $units = garden_waste_with_sacks();
                $units->[1]{ServiceTasks}{ServiceTask}{ServiceTaskSchedules}{ServiceTaskSchedule}[0]{EndDate}{DateTime} = $test->{end_date} . 'T00:00:00Z';
                return $units;
            });

            $mech->get_ok('/waste/12345/garden_renew');
            $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
            $mech->content_contains('<span id="cost_pa">' . $test->{sack_price} . '.00');
            $mech->content_contains('<span id="cost_now">' . $test->{sack_price} . '.00');
            $mech->submit_form_ok({ with_fields => {
                name => 'Test McTest',
                email => 'test@example.net',
            } });
            $mech->content_contains('1 sack subscription');
            $mech->content_contains($test->{sack_price} . '.00');
        };
    }

    restore_time;
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { kingston => { url => 'http://example.org' } },
        waste => { kingston => 1 },
        waste_features => { kingston => { garden_new_disabled => 1 } },
        payment_gateway => { kingston => { ggw_cost_renewal => 2000 } },
    },
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetEventsForObject', sub { [] });
    $echo->mock('GetTasks', sub { [] });
    $echo->mock('GetPointAddress', sub {
        return {
            Id => '12345',
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.408688, Longitude => -0.304465 } },
            Description => '2 Example Street, Kingston, KT1 1AA',
        };
    });
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
    mock_CancelReservedSlotsForEvent($echo);

    subtest 'check no sub when disabled' => sub {
        set_fixed_time('2021-03-09T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Subscribe to garden waste subscription', "subscribe disabled");
        $mech->get_ok('/waste/12345/garden');
        is $mech->uri->path, '/waste/12345', 'link redirect to bin list if subscribe when disabled';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { kingston => { url => 'http://example.org' } },
        waste => { kingston => 1 },
        waste_features => { kingston => {
            garden_renew_disabled => 1,
            garden_modify_disabled => 1,
        } },
        payment_gateway => { kingston => { ggw_cost_renewal => 2000 } },
    },
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetEventsForObject', sub { [] });
    $echo->mock('GetTasks', sub { [] });
    $echo->mock('GetPointAddress', sub {
        return {
            Id => '12345',
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.408688, Longitude => -0.304465 } },
            Description => '2 Example Street, Kingston, KT1 1AA',
        };
    });
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
    mock_CancelReservedSlotsForEvent($echo);

    subtest 'check no renew when disabled' => sub {
        set_fixed_time('2021-03-05T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Your subscription is soon due for renewal', "renewal disabled");
        $mech->get_ok('/waste/12345/garden_renew');
        is $mech->uri->path, '/waste/12345', 'link redirect to bin list if renewal when disabled';
    };

    subtest 'check no modify when disabled' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Change your garden waste subscription', "modify disabled");
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/waste/12345', 'link redirect to bin list if modify when disabled';
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
        bin_type => 1915,
        payment_method => 'credit_card',
        @_
    );
    $report->discard_changes;
    is $report->category, 'Garden Subscription', 'correct category on report';
    is $report->title, "Garden Subscription - $params{type}", 'correct title on report';
    is $report->get_extra_field_value('payment_method'), $params{payment_method}, 'correct payment method on report';
    is $report->get_extra_field_value('Paid_Container_Quantity'), $params{quantity}, 'correct bin count';
    is $report->get_extra_field_value('Paid_Container_Type'), $params{bin_type}, 'correct bin type';
    if ($params{new_bins}) {
        is $report->get_extra_field_value('Container_Type'), $params{bin_type}, 'correct container request bin type';
        is $report->get_extra_field_value('Quantity'), $params{new_bins}, 'correct container request count';
    }
    is $report->state, $params{state}, 'report state correct';
    if ($params{state} eq 'unconfirmed') {
        is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
    }
}

sub check_amend_extra_data_pre_confirm {
    my $report = shift;
    ok $report, "report passed to check_extra_data_pre_confirm";
    return unless $report;

    my %params = (
        state => 'unconfirmed',
        quantity => 1,
        new_bins => 1,
        bin_type => 1915,
        payment_method => 'credit_card',
        @_
    );
    $report->discard_changes;
    is $report->category, 'Amend Garden Subscription', 'correct category on report';
    is $report->title, "Garden Subscription - Amend", 'correct title on report';
    is $report->get_extra_field_value('payment_method'), $params{payment_method}, 'correct payment method on report';
    is $report->get_extra_field_value('Additional_Container_Quantity'), $params{quantity}, 'correct bin count';
    is $report->get_extra_field_value('Additional_Collection_Container_Type'), $params{bin_type}, 'correct bin type';
    if ($params{new_bins}) {
        is $report->get_extra_field_value('Container_Ordered_Type'), $params{bin_type}, 'correct container request bin type';
        is $report->get_extra_field_value('Container_Ordered_Quantity'), $params{new_bins}, 'correct container request count - one more';
    }
    is $report->state, $params{state}, 'report state correct';
}

sub check_extra_data_post_confirm {
    my $report = shift;
    my %params = @_;
    $report->discard_changes;
    is $report->state, 'confirmed', 'report confirmed';
    is $report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
    is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
}

sub check_removal_data_and_emails {
    my ($mech, $report) = @_;

    my ($removal) = @{$report->get_extra_metadata('grouped_ids')};
    $removal = FixMyStreet::DB->resultset("Problem")->find($removal);
    is $removal->category, 'Request new container';
    is $removal->get_extra_field_value('Container_Type'), 39, 'correct bin type';
    is $removal->get_extra_field_value('Action'), '2', 'correct container request action';
    is $removal->get_extra_field_value('Reason'), '8', 'correct container request reason';
    is $removal->get_extra_field_value('service_id'), 979;

    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my @emails = $mech->get_email;
    my $body1 = $mech->get_text_body_from_email($emails[1]);
    my $body2 = $mech->get_text_body_from_email($emails[3]);
    if ($body1 =~ /Your request to/) {
        ($body1, $body2) = ($body2, $body1);
    }
    like $body2, qr/Request Garden waste bin \(240L\) collection/;
    like $body1, qr/Number of bin subscriptions: 1/;
    like $body1, qr/Bins to be removed: 1/;
    like $body1, qr/Total:.*?20.00/;
}

sub mock_CancelReservedSlotsForEvent {
    shift->mock( 'CancelReservedSlotsForEvent', sub {
        my (undef, $guid) = @_;
        ok $guid, 'non-nil GUID passed to CancelReservedSlotsForEvent';
    } );
}

done_testing;
