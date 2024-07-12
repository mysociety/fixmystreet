use utf8;
use JSON::MaybeXS;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2500, 'Merton Borough Council', {}, { cobrand => 'merton' });
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
    { code => 'Bin_Detail_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Bin_Detail_Container', required => 1, automated => 'hidden_field' },
    { code => 'Bin_Detail_Type', required => 1, automated => 'hidden_field' },
    { code => 'End_Date', required => 1, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
);
my $change_address_contact = create_contact({ category => 'Garden Subscription Address Change', email => 'garden_address_change@example.com'},
    { code => 'staff_form', automated => 'hidden_field' },
    { code => 'new_address', description => 'New address', required => 1, datatype => 'text' },
    { code => 'old_address', descrption => 'Old address', required => 1, datatype => 'text' },
    { code => 'notice', variable => 'false', description => 'Only fill this in if they confirm they have moved to the new property.'},
);
$change_address_contact->remove_extra_field('service_id');
$change_address_contact->remove_extra_field('uprn');
$change_address_contact->remove_extra_field('property_id');

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
            TaskTypeId => 2239,
            Data => { ExtensibleDatum => [ {
                DatatypeName => 'SLWP - Containers',
                ChildData => { ExtensibleDatum => [ {
                    DatatypeName => 'Quantity',
                    Value => 1,
                }, {
                    DatatypeName => 'Container Type',
                    Value => 24,
                } ] },
            } ] },
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

sub garden_waste_only_refuse_sacks {
    return [ {
        Id => 1001,
        ServiceId => 405,
        ServiceName => 'Refuse collection',
        ServiceTasks => { ServiceTask => {
            Id => 400,
            TaskTypeId => 2242,
            Data => { ExtensibleDatum => [ {
                DatatypeName => 'SLWP - Containers',
                ChildData => { ExtensibleDatum => [ {
                    DatatypeName => 'Quantity',
                    Value => 1,
                }, {
                    DatatypeName => 'Container Type',
                    Value => 1,
                } ] },
            } ] },
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
    ALLOWED_COBRANDS => 'merton',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { merton => { url => 'http://example.org', nlpg => 'https://example.com/%s' } },
        waste => { merton => 1 },
    },
}, sub {
    my $lwp = Test::MockModule->new('LWP::UserAgent');
    $lwp->mock('get', sub {
        my ($ua, $url) = @_;
        return $lwp->original('get')->(@_) unless $url =~ /example.com/;
        my ($uprn, $area) = (1000000002, "MERTON");
        ($uprn, $area) = (1000000004, "KINGSTON UPON THAMES") if $url =~ /1000000004/;
        my $j = '{ "results": [ { "LPI": { "UPRN": ' . $uprn . ', "LOCAL_CUSTODIAN_CODE_DESCRIPTION": "' . $area . '" } } ] }';
        return HTTP::Response->new(200, 'OK', [], $j);
    });
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetEventsForObject', sub { [] });
    $echo->mock('GetTasks', sub { [] });
    $echo->mock('FindPoints', sub { [
        { Description => '2 Example Street, Merton, SM2 5HF', Id => '12345', SharedRef => { Value => { anyType => 1000000002 } } },
        { Description => '3 Example Street, Kingston, SM2 5HF', Id => '14345', SharedRef => { Value => { anyType => 1000000004 } } },
    ] });
    $echo->mock('GetPointAddress', sub {
        my ($self, $id) = @_;
        return {
            Id => $id,
            SharedRef => { Value => { anyType => $id == 14345 ? '1000000004' : '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.400975, Longitude => -0.19655 } },
            Description => '2/3 Example Street, Merton, SM2 5HF',
        };
    });
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
    mock_CancelReservedSlotsForEvent($echo);

    subtest 'Look up of address not in correct borough' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'SM2 5HF' } });
        $mech->submit_form_ok({ with_fields => { address => '14345' } });
        $mech->content_contains('No address on record');
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'SM2 5HF' } });
        $mech->submit_form_ok({ with_fields => { address => '12345' } });
        $mech->content_lacks('No address on record');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'merton',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { merton => { url => 'http://example.org' } },
        waste => { merton => 1 },
        waste_features => { merton => {
            dd_disabled => 1,
        } },
        payment_gateway => { merton => {
            cc_url => 'http://example.com',
            ggw_cost => 8978,
            ggw_sacks_cost => 8978,
            ggw_new_bin_first_cost => 0,
            ggw_new_bin_cost => 0,
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
    $p->update_extra_field({ name => 'property_id', value => '12345' });
    $p->update;

    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('GetEventsForObject', sub { [] });
    $echo->mock('GetTasks', sub { [] });
    $echo->mock('FindPoints', sub { [
        { Description => '1 Example Street, Merton, SM2 5HF', Id => '11345', SharedRef => { Value => { anyType => 1000000001 } } },
        { Description => '2 Example Street, Merton, SM2 5HF', Id => '12345', SharedRef => { Value => { anyType => 1000000002 } } },
        { Description => '3 Example Street, Merton, SM2 5HF', Id => '14345', SharedRef => { Value => { anyType => 1000000004 } } },
    ] });
    $echo->mock('GetPointAddress', sub {
        return {
            Id => '12345',
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.400975, Longitude => -0.19655 } },
            Description => '2 Example Street, Merton, ',
        };
    });
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);
    mock_CancelReservedSlotsForEvent($echo);

    my $sent_params = {};
    my $call_params = {};
    my $pay = Test::MockModule->new('Integrations::Adelante');

    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = shift;
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
        return {
            UID => '12345',
            Link => 'http://example.org/faq',
        };
    });
    my $query_return = { Status => 'Authorised', PaymentID => '54321' };
    $pay->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return $query_return;
    });

    subtest 'Garden type lookup' => sub {
        set_fixed_time('2021-03-09T17:00:00Z');
        $mech->get_ok('/waste?type=garden');
        $mech->submit_form_ok({ with_fields => { postcode => 'SM2 5HF' } });
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
        $mech->submit_form_ok({ with_fields => { postcode => 'SM2 5HF' } });
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
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin240' } });
        $mech->submit_form_ok({ with_fields => { existing => 'yes' } });
        $mech->content_contains('Please specify how many bins you already have');
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 0 } });
        $mech->content_contains('Existing bin count must be between 1 and 3');
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 7 } });
        $mech->content_contains('Existing bin count must be between 1 and 3');
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
        $mech->content_contains('The total number of bins cannot exceed 3');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 7,
                bins_wanted => 0,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 1 and 3');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 7,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Value must be between 1 and 3');

        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin240' } });
        $mech->submit_form_ok({ with_fields => { existing => 'yes', existing_number => 2 } });
        $form = $mech->form_with_fields( qw(current_bins bins_wanted payment_method) );
        ok $form, "form found";
        $mech->content_like(qr#Total to pay now: £<span[^>]*>179.56#, "initial cost set correctly");
        is $mech->value('current_bins'), 2, "current bins is set to 2";
    };

    subtest 'check new sub credit card payment' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin140' } });
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
        $mech->content_contains('£89.78');
        $mech->content_contains('1 140L bin');
        $mech->submit_form_ok({ with_fields => { goto => 'details' } });
        $mech->content_contains('<span id="cost_pa">89.78');
        $mech->content_contains('<span id="cost_now">89.78');
        $mech->submit_form_ok({ with_fields => {
                current_bins => 0,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{reference}, 'LBM-GWS-' . $new_report->id;
        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';
        check_extra_data_pre_confirm($new_report, bin_type => 27);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report);

        $mech->content_contains('Containers typically arrive within two weeks');
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        # Someone double-clicked
        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report);
        $mech->content_contains('Containers typically arrive within two weeks');
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?89.78/;
    };

    subtest 'check new sub credit card payment with no bins required' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin240' } });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 1,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£89.78');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';
        check_extra_data_pre_confirm($new_report, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        unlike $body, qr/Bins to be delivered/;
        like $body, qr/Total:.*?89.78/;
    };

    subtest 'check new sub credit card payment with one less bin required' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin140' } });
        $mech->submit_form_ok({ with_fields => { existing => 'no' } });
        $mech->submit_form_ok({ with_fields => {
                current_bins => 2,
                bins_wanted => 1,
                payment_method => 'credit_card',
                name => 'Test McTest',
                email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£89.78');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';
        check_extra_data_pre_confirm($new_report, bin_type => 27, new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be removed: 1/;
        like $body, qr/Total:.*?89.78/;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'check modify sub credit card payment' => sub {
        set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/auth', 'have to be logged in to modify subscription';
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('2 bins');
        $mech->content_contains('179.56');
        $mech->content_contains('89.78');
        $mech->submit_form_ok({ with_fields => { goto => 'alter' } });
        $mech->content_contains('<span id="cost_per_year">179.56');
        $mech->content_contains('<span id="pro_rata_cost">89.78');
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';

        check_extra_data_pre_confirm($new_report, type => 'Amend', quantity => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 2/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?89.78/;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_two_bins);
    subtest 'check modify sub credit card payment reducing bin count' => sub {
        set_fixed_time('2021-01-09T17:00:00Z'); # After sample data collection
        $sent_params = undef;

        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 2, bins_wanted => 1 } });
        $mech->content_contains('89.78');
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
        $mech->content_contains('Value must be between 1 and 3');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('1 bin');
        $mech->content_contains('89.78');
        $mech->submit_form_ok({ with_fields => { goto => 'intro' } });
        $mech->content_contains('<span id="cost_pa">89.78');
        $mech->content_contains('<span id="cost_now">89.78');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';

        check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Thank you for renewing/;
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Total:.*?89.78/;
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
        $mech->content_contains('The total number of bins cannot exceed 3');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 2,
            payment_method => 'credit_card',
            name => 'New McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('179.56');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        is $sent_params->{items}[0]{reference}, 'LBM-GWS-' . $new_report->id;
        is $sent_params->{name}, 'New McTest', 'correct amount used';

        check_extra_data_pre_confirm($new_report, type => 'Renew', quantity => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 2/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?179.56/;
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
        $mech->content_contains('89.78');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report);

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be removed: 1/;
        like $body, qr/Total:.*?89.78/;
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

    # subtest 'cancel credit card sub, no public users' => sub {
    #     $mech->log_in_ok($user->email);
    #     $mech->get_ok('/waste/12345/garden_cancel');
    #     is $mech->uri->path, '/waste/12345', 'redirected';
    # };

    subtest 'cancel credit card sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org', confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            undef,
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Bin_Detail_Container'), 26, 'correct container request bin type';
        is $new_report->get_extra_field_value('Bin_Detail_Type'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Bin_Detail_Quantity'), 1, 'correct container request count';
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
        extra => { '@>' => encode_json({ "_fields" => [ { name => "property_id", value => '12345' } ] }) },
    },
    {
        order_by => { -desc => 'id' }
    })->first;

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_only_refuse_sacks);

    subtest 'sacks, subscribing to a bin' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin240' } });
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
        $mech->content_contains('£89.78');
        $mech->content_contains('1 240L bin');
        $mech->submit_form_ok({ with_fields => { goto => 'details' } });
        $mech->content_contains('<span id="cost_pa">89.78');
        $mech->content_contains('<span id="cost_now">89.78');
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
            current_bins => 0,
            bins_wanted => 1,
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($new_report);

        $mech->content_contains('Containers typically arrive within two weeks');
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Number of bin subscriptions: 1/;
        like $body, qr/Bins to be delivered: 1/;
        like $body, qr/Total:.*?89.78/;
    };

    subtest 'sacks, subscribing' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'sack' } });
        $mech->content_like(qr#Total per year: £<span[^>]*>89.78#, "initial cost correct");
        $mech->content_lacks('"cheque"');
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->content_contains('Test McTest');
        $mech->content_contains('£89.78');
        $mech->content_contains('1 sack subscription');
        $mech->submit_form_ok({ with_fields => { goto => 'sacks_details' } });
        $mech->content_contains('<span id="cost_pa">89.78');
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net'
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, bin_type => 28);

        $mech->get('/waste/pay/xx/yyyyyyyyyyy');
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get("/waste/pay_complete/$report_id/NOTATOKEN");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($new_report);

        $mech->content_contains('Containers typically arrive within two weeks');
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Garden waste sack collection: 1 roll/;
        unlike $body, qr/Number of bin subscriptions/;
        like $body, qr/Total:.*?89.78/;
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_bin_with_refuse_sacks);

    subtest 'refuse sacks, garden bin, no choice' => sub {
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            current_bins => 1,
            bins_wanted => 1,
            payment_method => 'credit_card',
            name => 'Test McTest',
            email => 'test@example.net',
        } });
        $mech->content_contains('1 bin');
        $mech->content_contains('89.78');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';
        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, type => 'Renew', bin_type => 26, new_bins => 0);
    };

    subtest 'garden bin, no renewing as sacks' => sub {
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            bins_wanted => 1,
            name => 'Test McTest',
            email => 'test@example.net',
            payment_method => 'credit_card',
        } });
        $mech->content_contains('1 bin');
        $mech->content_contains('89.78');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';
        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Garden waste sack collection: 1 roll/;
        like $body, qr/Total:.*?89\.78/;
    };

    subtest 'refuse sacks, garden bin, can modify' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Modify your garden waste subscription');
        $mech->content_lacks('Order more garden sacks');
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->content_lacks('<span id="pro_rata_cost">89.78');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->content_contains('current_bins');
        $mech->content_contains('bins_wanted');
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2, name => 'Test McTest' } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';
        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, type => 'Amend', quantity => 2);
    };

    subtest 'refuse sacks, garden bin, cancelling' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org', confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            undef,
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Bin_Detail_Container'), 26, 'correct container request bin type';
        is $new_report->get_extra_field_value('Bin_Detail_Type'), 2, 'correct container request action';
        is $new_report->get_extra_field_value('Bin_Detail_Quantity'), 1, 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_with_sacks);

    subtest 'sacks, renewing' => sub {
        FixMyStreet::Script::Reports::send();
        $mech->clear_emails_ok;

        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            bins_wanted => 2,
            name => 'Test McTest',
            email => 'test@example.net',
            payment_method => 'credit_card',
        } });
        $mech->content_contains('2 sack subscriptions');
        $mech->content_contains('179.56');
        $mech->submit_form_ok({ with_fields => { goto => 'sacks_details' } });
        $mech->content_contains('<span id="cost_pa">179.56');
        $mech->content_contains('<span id="cost_now">179.56');
        $mech->submit_form_ok({ with_fields => {
            payment_method => 'credit_card',
        } });
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 17956, 'correct amount used';
        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, type => 'Renew', bin_type => 28, quantity => 2, new_bins => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Garden waste sack collection: 2 rolls/;
        unlike $body, qr/Number of bin subscriptions/;
        like $body, qr/Total:.*?179\.56/
    };

    subtest 'sacks, not renewing as a bin' => sub {
        $mech->clear_emails_ok;

        $mech->get_ok('/waste/12345/garden_renew');
        $mech->submit_form_ok({ with_fields => {
            bins_wanted => 2,
            name => 'Test McTest',
            email => 'test@example.net',
            payment_method => 'credit_card',
        } });
        $mech->content_contains('2 sack subscriptions');
        $mech->content_contains('179.56');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        is $sent_params->{items}[0]{amount}, 17956, 'correct amount used';
        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, type => 'Renew', bin_type => 28, quantity => 2, new_bins => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");

        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Garden waste sack collection: 2/;
        unlike $body, qr/Number of bin subscriptions:/;
        like $body, qr/Total:.*?179\.56/
    };

    subtest 'sacks, cannot modify, cannot buy more' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Modify your garden waste subscription');
        $mech->content_lacks('Order more garden sacks');
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/waste/12345', 'redirected';
    };

    subtest 'sacks, cancelling' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org', confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            undef,
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->get_extra_field_value('Bin_Detail_Container'), '', 'correct container request bin type';
        is $new_report->get_extra_field_value('Bin_Detail_Type'), '', 'correct container request action';
        is $new_report->get_extra_field_value('Bin_Detail_Quantity'), '', 'correct container request count';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'check staff renewal' => sub {
        $query_return = { Status => 'Authorised', PaymentID => '54321', MPOSID => 'mposid', AuthCode => 'authcode' };
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);
        foreach ({ email => 'a_user@example.net' }, { phone => '07700900002' }) {
            $mech->get_ok('/waste/12345/garden_renew');
            $mech->submit_form_ok({ with_fields => {
                name => 'a user',
                %$_, # email or phone,
                current_bins => 1,
                bins_wanted => 1,
                payment_method => 'credit_card',
            }});
            $mech->content_contains('89.78');

            $mech->waste_submit_check({ with_fields => { tandc => 1 } });
            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
            check_extra_data_pre_confirm($new_report, type => 'Renew', new_bins => 0, payment_method => 'csc');

            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            check_extra_data_post_confirm($new_report, 1);

            is $new_report->get_extra_field_value('MPOSID'), 'mposid', 'correct staff extra payment data';

            $new_report->delete; # Otherwise next test sees this as latest
        }
        $query_return = { Status => 'Authorised', PaymentID => '54321' };
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
        $mech->content_contains('179.56');
        $mech->content_contains('89.78');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($report, type => 'Amend', quantity => 2, payment_method => 'csc');

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($report, 1);
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
        $mech->content_contains('89.78');
        $mech->content_lacks('Continue to payment');
        $mech->content_contains('Confirm changes');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        $mech->content_lacks($staff_user->email);

        my $content = $mech->content;
        my ($id) = ($content =~ m#reference number is <strong>.*?(\d+)<#);
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

    subtest 'staff change address for sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/');
        $mech->content_contains('Report an address change', "contains link to address change form");
        $mech->follow_link_ok({ text => 'Report an address change' });
        $mech->content_contains('Only fill this in if they confirm they have moved to the new property.', 'contains notice');
        $mech->submit_form_ok({ with_fields => {
            extra_new_address => 'New Address',
            extra_old_address => 'Old Address',
        } });
        $mech->submit_form_ok({ with_fields => {
            email => 'resident@example.org',
            name => 'Arthur Address-Change',
        } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your enquiry has been submitted');

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Garden Subscription Address Change', 'correct category on report';
        is $new_report->get_extra_field_value('new_address'), 'New Address', 'correct new address on report';
        is $new_report->get_extra_field_value('old_address'), 'Old Address', 'correct old address on report';
        is $new_report->get_extra_metadata('no_echo'), 1, 'metadata set to indicate not sent to echo';
        is $new_report->send_state, 'sent', 'report marked as sent';
    };

    subtest 'cancel staff sub' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org', confirm => 1 } });
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            { },
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->state, 'confirmed', 'report confirmed';
        is $new_report->get_extra_metadata('contributed_by'), $staff_user->id;
        is $new_report->get_extra_metadata('contributed_as'), 'another_user';
    };

    $echo->mock('GetServiceUnitsForObject', \&garden_waste_no_bins);
    subtest 'staff create new subscription' => sub {
        $mech->log_out_ok;
        $mech->log_in_ok($staff_user->email);
        $mech->clear_emails_ok;
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin140' } });
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
        $mech->content_contains('£89.78');
        $mech->content_contains('1 140L bin');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
        check_extra_data_pre_confirm($new_report, bin_type => 27, payment_method => 'csc');

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report, 1);
        is $new_report->name, 'Test McTest', 'non staff user name';
        is $new_report->user->email, 'test@example.net', 'non staff email';

        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        is $new_report->user->email, 'test@example.net';
        is $new_report->get_extra_metadata('contributed_by'), $staff_user->id;
        $new_report->delete; # Otherwise next test sees this as latest
    };

    subtest 'staff create new subscription with a cheque' => sub {
        $mech->get_ok('/waste/12345/garden');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { container_choice => 'bin240' } });
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
        $mech->content_contains('£89.78');
        $mech->content_contains('1 240L bin');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        my ($report_id) = $mech->content =~ m#reference number is <strong>(\d+)#;
        my $report = FixMyStreet::DB->resultset('Problem')->search( { id => $report_id } )->first;

        check_extra_data_pre_confirm($report, payment_method => 'cheque', state => 'confirmed');
        is $report->get_extra_field_value('LastPayMethod'), 4, 'correct echo payment method field';
        is $report->get_extra_metadata('chequeReference'), 'Cheque123', 'cheque reference saved';
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
        $report->delete; # Otherwise next test sees this as latest
    };

    # remove all reports
    remove_test_subs( 0 );
    $echo->mock('GetServiceUnitsForObject', \&garden_waste_one_bin);

    subtest 'modify sub with no existing waste sub - credit card payment' => sub {
        set_fixed_time('2021-01-09T17:00:00Z');
        $mech->log_out_ok();
        $mech->get_ok('/waste/12345/garden_modify');
        is $mech->uri->path, '/auth', 'have to be logged in to modify subscription';
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/garden_modify');
        $mech->submit_form_ok({ with_fields => { task => 'modify' } });
        $mech->submit_form_ok({ with_fields => { current_bins => 1, bins_wanted => 2 } });
        $mech->content_contains('179.56');
        $mech->content_contains('89.78');
        $mech->waste_submit_check({ with_fields => { tandc => 1 } });

        is $sent_params->{items}[0]{amount}, 8978, 'correct amount used';

        my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        check_extra_data_pre_confirm($new_report, type => 'Amend', quantity => 2);

        $mech->get_ok("/waste/pay_complete/$report_id/$token");
        check_extra_data_post_confirm($new_report);
        $mech->content_like(qr#/waste/12345">Show upcoming#, "contains link to bin page");
    };

    remove_test_subs( 0 );

    subtest 'cancel credit card sub with no record in waste' => sub {
        set_fixed_time('2021-03-09T17:00:00Z'); # After sample data collection
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345/garden_cancel');
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org', confirm => 1 } });

        my $new_report = FixMyStreet::DB->resultset('Problem')->search(
            undef,
            { order_by => { -desc => 'id' } },
        )->first;

        is $new_report->category, 'Cancel Garden Subscription', 'correct category on report';
        is $new_report->get_extra_field_value('End_Date'), '2021-03-09', 'cancel date set to current date';
        is $new_report->state, 'confirmed', 'report confirmed';
    };

    remove_test_subs( 0 );
};

sub get_report_from_redirect {
    my $url = shift;

    return ('', '', '') unless $url;

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
    ok $report, "report passed to check_extra_data_pre_confirm";
    return unless $report;

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
        is $report->get_extra_field_value('Bin_Delivery_Detail_Container'), $params{bin_type_delivery} || $params{bin_type}, 'correct container request bin type';
        is $report->get_extra_field_value('Bin_Delivery_Detail_Containers'), $params{action}, 'correct container request action';
        is $report->get_extra_field_value('Bin_Delivery_Detail_Quantity'), $params{new_bins}, 'correct container request count';
    }
    is $report->state, $params{state}, 'report state correct';
}

sub check_extra_data_post_confirm {
    my ($report, $pay_method) = @_;
    $pay_method ||= 2;
    ok $report, "report passed to check_extra_data_post_confirm";
    return unless $report;

    $report->discard_changes;
    is $report->state, 'confirmed', 'report confirmed';
    is $report->get_extra_field_value('LastPayMethod'), $pay_method, 'correct echo payment method field';
    is $report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
    is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
}

sub mock_CancelReservedSlotsForEvent {
    shift->mock( 'CancelReservedSlotsForEvent', sub {
        my (undef, $guid) = @_;
        ok $guid, 'non-nil GUID passed to CancelReservedSlotsForEvent';
    } );
}

done_testing;
