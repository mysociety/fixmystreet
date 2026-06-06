use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use Path::Tiny;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $user
    = $mech->create_user_ok( 'bob@example.org', name => 'Original Name' );
my $body_user = $mech->create_user_ok('body@example.org');

my $body = $mech->create_body_ok( 2480, 'Kingston upon Thames Council',
    { comment_user => $body_user, cobrand => 'kingston' } );
$body->set_extra_metadata(
    wasteworks_config => {
        base_price => '6100',
        band1_price => '4000',
        band1_max => 4,
        items_per_collection_max => 8,
        per_item_costs => 0,
        show_location_page => 'users',
        show_individual_notes => 1,
        item_list => [
            { bartec_id => '83', name => 'Bath' },
            { bartec_id => '84', name => 'Bathroom Cabinet /Shower Screen' },
            { bartec_id => '85', name => 'Bicycle' },
            { bartec_id => '3', name => 'BBQ' },
            { bartec_id => '6', name => 'Bookcase, Shelving Unit' },
        ],
    },
);
$body->update;

my $bulky_contact = $mech->create_contact_ok(
    body => $body,
    category => 'Bulky collection',
    email => '1636@test.com',
    group => ['Waste'],
    extra => { type => 'waste' },
);
$bulky_contact->set_extra_fields(
    { code => 'property_id', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 0, automated => 'hidden_field' },
    { code => 'payment' },
    { code => 'payment_method' },
    { code => 'Collection_Date_-_Bulky_Items' },
    { code => 'TEM_-_Bulky_Collection_Item' },
    { code => 'TEM_-_Bulky_Collection_Description' },
    { code => 'Exact_Location' },
    { code => 'GUID' },
    { code => 'reservation' },
    { code => 'First_Date_Offered_-_Bulky' },
);
$bulky_contact->update;

my $missed_contact = $mech->create_contact_ok(
    body => $body,
    category => 'Report missed collection',
    email => 'missed@example.org',
    group => ['Waste'],
    extra => { type => 'waste' },
);
$missed_contact->set_extra_fields(
    { code => 'property_id', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 0, automated => 'hidden_field' },
    { code => 'Exact_Location', required => 0, automated => 'hidden_field' },
    { code => 'Original_Event_ID', required => 0, automated => 'hidden_field' },
    { code => 'Notes', required => 0, automated => 'hidden_field' },
);
$missed_contact->update;

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'kingston',
    COBRAND_FEATURES => {
        waste => { kingston => 1 },
        waste_features => {
            kingston => {
                bulky_enabled => 1,
                bulky_missed => 1,
                bulky_tandc_link => 'tandc_link',
                echo_update_failure_email => 'fail@example.com',
            },
        },
        echo => {
            kingston => {
                bulky_address_types => [ 1, 7 ],
                bulky_service_id => 986,
                bulky_event_type_id => 3130,
                url => 'http://example.org',
                nlpg => 'https://example.com/%s',
            },
        },
        payment_gateway => { kingston => {
            cc_url => 'http://example.com',
            hmac => '1234',
            hmac_id => '1234',
            scpID => '1234',
            company_name => 'rbk',
            customer_ref => 'customer-ref',
            bulky_customer_ref => 'customer-ref-bulky',
        } },
    },
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 2238}] } );
    $echo->mock( 'GetTasks',                 sub { [] } );
    $echo->mock( 'GetEventsForObject',       sub { [] } );
    $echo->mock( 'CancelReservedSlotsForEvent', sub {
        my (undef, $guid) = @_;
        ok $guid, 'non-nil GUID passed to CancelReservedSlotsForEvent';
    } );
    $echo->mock( 'FindPoints', sub {
            [   {   Description => '2 Example Street, Kingston, KT1 1AA',
                    Id          => '12345',
                    SharedRef   => { Value => { anyType => 1000000002 } }
                },
            ]
    } );
    $echo->mock( 'GetPointAddress', sub {
        return {
            PointAddressType => {
                Id   => 1,
                Name => 'Detached',
            },

            Id        => '12345',
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            Coordinates => {
                GeoPoint =>
                    { Latitude => 51.408688, Longitude => -0.304465 }
            },
            Description => '2 Example Street, Kingston, KT1 1AA',
        };
    } );
    $echo->mock('ReserveAvailableSlotsForEvent', sub {
        return [
            {
                StartDate => { DateTime => '2023-07-01T00:00:00Z' },
                EndDate => { DateTime => '2023-07-02T00:00:00Z' },
                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                Reference => 'reserve1==',
            }, {
                StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                Reference => 'reserve2==',
            }, {
                StartDate => { DateTime => '2023-07-15T00:00:00Z' },
                EndDate => { DateTime => '2023-07-16T00:00:00Z' },
                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                Reference => 'reserve3==',
            },
        ]
    } );

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

    # Make a bulky report
    $mech->log_in_ok( $user->email );
    $mech->get_ok('/waste/12345/bulky');
    $mech->submit_form_ok;
    $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email, phone => '44 07 111 111 111' }});
    $mech->submit_form_ok(
        { with_fields => { chosen_date => '2023-07-01T00:00:00;reserve1==::reserve4==;2023-06-25T10:10:00' } }
    );
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => {
                'item_1' => 'BBQ',
            },
        },
    );
    $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
    $mech->waste_submit_check({ with_fields => { tandc => 1 } });

    my ( $token, $bulky_report, $bulky_report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );
    $mech->get_ok("/waste/pay_complete/$bulky_report_id/$token");
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my $catch_email = $mech->get_email;
    $mech->clear_emails_ok;
    $bulky_report->discard_changes;
    is $bulky_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

    subtest 'Dispute about failed bulky collection' => sub {
        $bulky_report->update( { external_id => 'a-guid' } );

        # Mock failed collection.
        my %event_defaults = (
            Id => '8004',
            ClientReference => '12345',
            Guid => 'a-guid',
            ServiceId => 986, # Bulky
            EventTypeId => 3130, # Bulky collection
            EventStateId => 19185, # Not Completed
            EventDate => { DateTime => '2023-07-01T00:00:00Z' },
            ResolvedDate => { DateTime => '2023-07-01T15:00:00Z' },
        );

        subtest 'Blocked resolution' => sub {
            $echo->mock('GetEventsForObject', sub { [ {
                %event_defaults,
                EventStateId => 19187, # Cancelled
            } ] });

            subtest 'Raising a dispute never available' => sub {
                set_fixed_time('2023-07-01T14:59:59Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just before window opens');

                set_fixed_time('2023-07-05T00:00:00Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just after window closes');

                set_fixed_time('2023-07-01T15:00:01Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just after window opens');

                set_fixed_time('2023-07-04T23:59:00Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just before window closes');
            };

            # XXX
            # subtest 'No dispute link in email' => sub {};
        };

        subtest 'Allowed resolution' => sub {
            $echo->mock('GetEventsForObject', sub { [ {
                %event_defaults,
                ResolutionCodeId => 466, # No access - Gate locked
            } ] });

            subtest 'Check dispute window' => sub {
                set_fixed_time('2023-07-01T14:59:59Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just before window opens');

                set_fixed_time('2023-07-05T00:00:00Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just after window closes');

                set_fixed_time('2023-07-01T15:00:01Z');
                $mech->get_ok('/waste/12345');
                $mech->content_contains('Report a problem with this missed collection', 'can report just after window opens');

                set_fixed_time('2023-07-04T23:59:00Z');
                $mech->get_ok('/waste/12345');
                $mech->content_contains('Report a problem with this missed collection', 'can report just before window closes');
            };

            subtest 'Follow dispute link' => sub {
                set_fixed_time('2023-07-01T15:00:01Z');
                $mech->content_contains(
                    '/enquiry?category=Missed+collection+dispute&amp;service_id=986&amp;booking_id=1'
                );
                # XXX Why no event_id?
                $mech->content_lacks('event_id');
                $mech->content_lacks('report_id');
                $mech->follow_link_ok({ text => 'Report a problem with this missed collection' });

                $mech->content_contains('Missed collection dispute');
                $mech->content_contains('your Bulky waste collection was not made');
                $mech->content_contains('No access - Gate locked');
                $mech->content_contains(
                    '/Raise_a_waste_dispute_in_Kingston?uprn=1000000002&service_id=986'
                );
                # XXX Why no event_id?
                $mech->content_lacks('&event_id=');
            };

            # XXX
            # subtest 'Correct dispute link in email' => sub {
            #     restore_time();

            #     my $comment = FixMyStreet::DB->resultset('Comment')->create(
            #         {
            #             user          => $body_user,
            #             problem_id    => $bulky_report->id,
            #             text          => 'No access - Gate locked',
            #             confirmed     => DateTime->now,
            #             problem_state => 'unable to fix',
            #             anonymous     => 0,
            #             mark_open     => 0,
            #             mark_fixed    => 0,
            #             state         => 'confirmed',
            #         }
            #     );

            #     set_fixed_time('2023-07-01T15:00:01Z');

            #     $mech->clear_emails_ok;
            #     FixMyStreet::Script::Alerts::send_updates();
            #     $mech->email_count_is(1);
            #     my $email = $mech->get_email;
            #     my $email_text = $mech->get_text_body_from_email($email);
            #     my $email_html = $mech->get_html_body_from_email($email);
            #     like $email_text, qr/No access - Gate locked/, 'Reason pulled from comment';
            #     like $email_text, qr/report a problem with this missed collection/, 'Report a problem text in text email';
            #     like $email_html, qr/No access - Gate locked/, 'Reason pulled from comment';
            #     like $email_html, qr/Our crews reported your bulky waste collection was not made/, 'extra bulky waste text included';
            #     like $email_html, qr/Report a problem with this missed collection/, 'Report a problem text in html email';
            #     # XXX Where is service_id?
            #     like $email_html, qr{enquiry\?category=Missed\+collection\+dispute&service_id=&booking_id=1}, 'HTML alert contains report link';

            #     $comment->delete;
            # };
        };

        subtest 'Existing dispute event' => sub {
            set_fixed_time('2023-07-02T15:00:01Z');

            # Mock failed collection plus dispute
            $echo->mock('GetEventsForObject', sub { [ {
                %event_defaults,
                ResolutionCodeId => 466, # No access - Gate locked
            }, {
                Id => '112112321',
                EventTypeId => 3143, # Dispute
                EventStateId => 0,
                ServiceId => 986, # Bulky
                EventDate => { DateTime => '2023-07-02T15:00:00Z' },
            } ] });

            $mech->get_ok('/waste/12345');
            $mech->content_lacks('Report a problem with this missed collection');
            $mech->content_contains('We are investigating the problem with this collection.');
        };
    };

    subtest 'Dispute about resolution of bulky missed collection report' => sub {
        my $completed_bulky_event = {
            Id => '8004',
            ClientReference => '12345',
            Guid => 'a-guid',
            ServiceId => 986, # Bulky
            EventTypeId => 3130, # Bulky collection
            EventStateId => 19184, # Completed
            EventDate => { DateTime => '2023-07-01T00:00:00Z' },
            ResolvedDate => { DateTime => '2023-07-01T15:00:00Z' },
            ResolutionCodeId => 232, # Completed on Scheduled Day (dunno if used, doesn't matter)
        };

        $echo->mock('GetEventsForObject', sub { [ $completed_bulky_event ] });

        # Make a missed collection report
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a bulky waste collection as missed');
        $mech->submit_form_ok({ form_number => 1 }, 'Follow link for reporting a missed bulky collection');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok();
        $mech->submit_form_ok({ form_number => 1 });
        $mech->content_contains('Submit missed bulky collection');
        $mech->submit_form_ok({ form_number => 3 });

        my $mc_report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        $mc_report->update({ external_id => 'b-guid' });

        my %missed_collection_report_event_defaults = (
            Id => '112112321',
            Guid => 'b-guid', # Must match missed collection report above
            EventTypeId => 3145, # Missed collection report
            EventStateId => 19242, # Not Completed
            ServiceId => 986, # Bulky
            EventDate => { DateTime => '2023-07-02T00:00:00Z' },
            ResolvedDate => { DateTime => '2023-07-02T15:00:00Z' },
        );

        subtest 'Blocked resolution' => sub {
            my $missed_collection_report_event = {
                %missed_collection_report_event_defaults,
                EventStateId => 19187, # Cancelled
            };

            # Mock 'completed' bulky report and missed collection report in Echo
            $echo->mock('GetEventsForObject', sub { [
                $completed_bulky_event, $missed_collection_report_event
            ] });

            subtest 'Raising a dispute never available' => sub {
                set_fixed_time('2023-07-01T14:59:59Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just before window opens');

                set_fixed_time('2023-07-05T00:00:00Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just after window closes');

                set_fixed_time('2023-07-01T15:00:01Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just after window opens');

                set_fixed_time('2023-07-04T23:59:00Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just before window closes');
            };

            # XXX
            # subtest 'No dispute link in email' => sub {};
        };

        subtest 'Resolution that allows dispute' => sub {
            my $missed_collection_report_event = {
                %missed_collection_report_event_defaults,
                ResolutionCodeId => 617, # No access - Parked vehicle
            };

            # Mock 'completed' bulky report and missed collection report in Echo
            $echo->mock('GetEventsForObject', sub { [
                $completed_bulky_event, $missed_collection_report_event
            ] });

            subtest 'Check dispute window' => sub {
                set_fixed_time('2023-07-02T14:59:59Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just before window opens');

                set_fixed_time('2023-07-05T00:00:00Z');
                $mech->get_ok('/waste/12345');
                $mech->content_lacks('Report a problem with this missed collection', 'cannot report just after window closes');

                set_fixed_time('2023-07-02T15:00:01Z');
                $mech->get_ok('/waste/12345');
                $mech->content_contains('Report a problem with this missed collection', 'can report just after window opens');

                set_fixed_time('2023-07-04T23:59:00Z');
                $mech->get_ok('/waste/12345');
                $mech->content_contains('Report a problem with this missed collection', 'can report just before window closes');
            };

            subtest 'Follow dispute link' => sub {
                set_fixed_time('2023-07-02T15:00:01Z');
                $mech->content_contains(
                    '/enquiry?category=Missed+collection+dispute&amp;service_id=986&amp;booking_id=1&amp;report_id=2&amp;event_id=112112321'
                );
                $mech->follow_link_ok({ text => 'Report a problem with this missed collection' });

                $mech->content_contains('Missed collection dispute');
                $mech->content_contains('your Bulky waste collection was not made');
                $mech->content_contains('No access - Parked vehicle');
                $mech->content_contains(
                    '/Raise_a_waste_dispute_in_Kingston?uprn=1000000002&service_id=986&event_id=112112321'
                );
            };

            # XXX
            # subtest 'Correct dispute link in email' => sub {
            #     restore_time();

            #     my $comment = FixMyStreet::DB->resultset('Comment')->create(
            #         {
            #             user          => $body_user,
            #             problem_id    => $mc_report->id,
            #             text          => 'No access - Parked vehicle',
            #             confirmed     => DateTime->now,
            #             problem_state => 'unable to fix',
            #             anonymous     => 0,
            #             mark_open     => 0,
            #             mark_fixed    => 0,
            #             state         => 'confirmed',
            #         }
            #     );

            #     set_fixed_time('2023-07-02T15:00:01Z');

            #     $mech->clear_emails_ok;
            #     FixMyStreet::Script::Alerts::send_updates();
            #     $mech->email_count_is(1);
            #     my $email = $mech->get_email;
            #     my $email_text = $mech->get_text_body_from_email($email);
            #     my $email_html = $mech->get_html_body_from_email($email);
            #     like $email_text, qr/No access - Parked vehicle/, 'Reason pulled from comment';
            #     like $email_text, qr/report a problem with this missed collection/, 'Report a problem text in text email';
            #     like $email_html, qr/No access - Parked vehicle/, 'Reason pulled from comment';
            #     like $email_html, qr/Our crews reported your collection was not made/, 'extra collection text included';
            #     like $email_html, qr/Report a problem with this missed collection/, 'Report a problem text in html email';
            #     like $email_html, qr{Raise_a_waste_dispute_in_Kingston\?uprn=1000000002&service_id=986}, 'HTML alert contains report link';

            #     $comment->delete;
            # };
        };

        subtest 'Completed missed bin report' => sub {
            set_fixed_time('2023-07-02T15:00:01Z');

            $echo->mock('GetEventsForObject', sub { [
                $completed_bulky_event,
                {
                    %missed_collection_report_event_defaults,
                    EventStateId => 19241, # Completed
                },
            ] });

            subtest 'Follow dispute link' => sub {
                $mech->get_ok('/waste/12345');
                $mech->content_contains(
                    '/enquiry?category=Missed+collection+dispute&amp;service_id=986&amp;booking_id=1&amp;report_id=2&amp;event_id=112112321'
                );
                $mech->follow_link_ok({ text => 'Report a problem with this missed collection' });
                $mech->content_contains('Missed collection dispute');
# XXX
# $mech->content_contains('your Bulky waste collection was completed');
                $mech->content_contains(
                    '/Raise_a_waste_dispute_in_Kingston?uprn=1000000002&service_id=986&event_id=112112321'
                );
            };
        };

        subtest 'Existing dispute event' => sub {
            set_fixed_time('2023-07-03T15:00:01Z');

            # Include mock of dispute event
            $echo->mock('GetEventsForObject', sub { [
                $completed_bulky_event,
                \%missed_collection_report_event_defaults,
                {
                    Id => '992992329',
                    EventTypeId => 3143, # Dispute
                    EventStateId => 0,
                    ServiceId => 986, # Bulky
                    EventDate => { DateTime => '2023-07-03T15:00:00Z' },
                },
            ] });

            $mech->get_ok('/waste/12345');
            $mech->content_lacks('Report a problem with this missed collection');
            $mech->content_contains('We are investigating the problem with this collection.');
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

done_testing;
