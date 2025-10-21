use CGI::Simple;
use Test::MockModule;
use Test::Output;
use MIME::Base64;
use Path::Tiny;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;
use FixMyStreet::SendReport::Open311;

my $mech = FixMyStreet::TestMech->new;
my $sample_file = path(__FILE__)->parent->child("zurich-logo_portal.x.jpg");

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Create test data
my $date = DateTime->now->subtract(days => 1)->strftime('%Y-%m-%dT%H:%M:%SZ');
my $user = $mech->create_user_ok( 'sutton@example.com', name => 'Sutton Council' );
my $normal_user = $mech->create_user_ok( 'user@example.com', name => 'Norma Normal' );
my $body = $mech->create_body_ok( 2498, 'Sutton Council', {
    can_be_devolved => 1, send_extended_statuses => 1, comment_user => $user,
    send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1,
    cobrand => 'sutton'
});
my $kingston = $mech->create_body_ok( 2480, 'Kingston upon Thames Council', {
    comment_user => $user,
    cobrand => 'kingston',
});
$user->update({ from_body => $body->id });
$user->user_body_permissions->create({ body => $body, permission_type => 'report_edit' });

FixMyStreet::DB->resultset('ResponseTemplate')->create({
    body_id => $body->id,
    auto_response => 1,
    title => 'Completed bulky waste',
    text => 'Your collection has now been completed',
    state => 'fixed - council',
});

$mech->create_contact_ok(
    body => $body,
    category => 'Graffiti',
    email => 'graffiti@example.org',
    send_method => 'Email',
);
foreach ([ missed => 'Report missed collection' ], [ 1638 => 'Garden Subscription' ], [ 1636 => 'Bulky collection' ]) {
    $mech->create_contact_ok(
        body => $body,
        email => $_->[0],
        category => $_->[1],
        send_method => 'Open311',
        endpoint => 'waste-endpoint',
        extra => { type => 'waste' },
        group => ['Waste'],
    );
}

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    latitude => 51.402096,
    longitude => 0.015784,
    category => 'Report missed collection',
    cobrand => 'sutton',
    cobrand_data => 'waste',
    areas => '2498',
    user => $user,
    send_method_used => 'Open311',
});
my $report = $reports[0];

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['sutton', 'fixmystreet'],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1 },
}, sub {
    subtest 'test waste duplicate' => sub {
        my $sender = FixMyStreet::SendReport::Open311->new(
            bodies => [ $body ], body_config => { $body->id => $body },
        );
        Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Missed Collection event already open for the property</description></error></errors>', 500);
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
        is $report->state, 'duplicate', 'State updated';
    };

    subtest 'test DD taking so long it expires' => sub {
        my $sender = FixMyStreet::SendReport::Open311->new(
            bodies => [ $body ], body_config => { $body->id => $body },
        );
        my $title = $report->title;
        $report->update({ title => "Garden Subscription - Renew" });
        Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Cannot renew this property, a new request is required</description></error></errors>', 500);
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
        is $report->get_extra_field_value("Request_Type"), 1, 'Type updated';
        is $report->title, "Garden Subscription - New";
        $report->update({ title => $title });
    };

    subtest 'test duplicate event at the Echo side' => sub {
        my $sender = FixMyStreet::SendReport::Open311->new(
            bodies => [ $body ], body_config => { $body->id => $body },
        );
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetEvent', sub { {
            Guid => 'a-guid',
            Id => 123,
        } } );
        Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Duplicate Event! Original eventID: 123</description></error></errors>', 500);
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
        is $sender->success, 1;
        is $report->external_id, 'a-guid';
    };

    subtest 'correct payment data sent across' => sub {
        $report->category('Garden Subscription');
        $report->set_extra_metadata(payment_reference => 'Code4321');
        $report->update_extra_field({ name => 'payment', value => '8300' });
        $report->state('confirmed');
        $report->update;
        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[Transaction_Number]'), 'Code4321';
        is $c->param('attribute[Payment_Amount]'), '83.00';
    };

    subtest '.com reports do not get branding/broken link' => sub {
        ok $mech->host("www.fixmystreet.com"), "change host to www";
        $mech->clear_emails_ok;
        $mech->log_in_ok($user->email);
        $mech->get_ok('/report/new?latitude=51.354679&longitude=-0.183895');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test graffiti",
                detail => 'Test graffiti details.',
                category => 'Graffiti',
            }
        }, "submit details");
        $mech->content_contains('Thank you for reporting');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        my $id = $report->id;
        ok $report, "Found the report";
        is $report->title, 'Test graffiti', 'Got the correct report';
        is $report->bodies_str, $body->id, 'Report was sent to parish';
        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Dear Sutton Council,\s+A user of FixMyStreet has submitted/;
        like $body, qr{http://www.example.org/report/$id};
    };

    subtest 'check payment code is censored' => sub {
        ok $mech->host("sutton.example.org"), "change host to Sutton";
        $mech->get_ok('/admin/report_edit/' . $report->id);
        $mech->content_contains('xxxx4321');
    };
};

$report->delete; # Not needed for next bit

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

subtest 'updating of waste reports' => sub {
    my $integ = Test::MockModule->new('SOAP::Lite');
    $integ->mock(call => sub {
        my ($cls, @args) = @_;
        my $method = $args[0]->name;
        if ($method eq 'GetEvent') {
            my ($key, $type, $value) = ${$args[3]->value}->value;
            my $external_id = ${$value->value}->value->value;
            my ($waste, $event_state_id, $resolution_code) = split /-/, $external_id;
            my $data = [];
            if ($external_id eq 'waste-with-image') {
                push @$data, {
                    DatatypeName => 'Post Collection Photo',
                    Value => encode_base64($sample_file->slurp_raw),
                };
            }
            return SOAP::Result->new(result => {
                Guid => $external_id,
                EventStateId => $event_state_id,
                EventTypeId => '1638',
                LastUpdatedDate => { OffsetMinutes => 60, DateTime => $date },
                ResolutionCodeId => $resolution_code,
                Data => { ExtensibleDatum => $data },
            });
        } elsif ($method eq 'GetEventType') {
            return SOAP::Result->new(result => {
                Workflow => { States => { State => [
                    { CoreState => 'New', Name => 'New', Id => 15001 },
                    { CoreState => 'Pending', Name => 'Unallocated', Id => 15002 },
                    { CoreState => 'Pending', Name => 'Allocated to Crew', Id => 15003 },
                    { CoreState => 'Closed', Name => 'Completed', Id => 15004 },
                    { CoreState => 'Closed', Name => 'Partially Completed', Id => 15005 },
                    { CoreState => 'Closed', Name => 'Not Completed', Id => 15006 },
                ] } },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    my @reports = $mech->create_problems_for_body(2, $body->id, 'Garden Subscription', {
        confirmed => \'current_timestamp',
        user => $normal_user,
        category => 'Garden Subscription',
        cobrand_data => 'waste',
        non_public => 1,
    });
    $reports[1]->update({ external_id => 'something-else' }); # To test loop
    $report = $reports[0];
    # Set last update to before the time of the first update we've mocked.
    $report->update({ lastupdate => $date });

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'sutton',
        COBRAND_FEATURES => {
            echo => { sutton => { url => 'https://www.example.org/' } },
            waste => { sutton => 1 }
        },
    }, sub {
        $mech->clear_emails_ok;

        $normal_user->create_alert($report->id, { cobrand => 'sutton', whensubscribed => $date });

        my $cobrand = FixMyStreet::Cobrand::Sutton->new;

        $report->update({ external_id => 'waste-15001-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 0, 'No new update';
        is $report->state, 'confirmed', 'No state change';

        $report->update({ external_id => 'waste-15002-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state investigating, Unallocated/;
        $report->discard_changes;
        is $report->comments->count, 1, 'A new update';
        my $update = $report->comments->first;
        is $update->text, 'Unallocated';
        is $report->state, 'investigating', 'A state change';

        $report->update({ external_id => 'waste-15003-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 1, 'No new update';
        is $report->state, 'investigating', 'State unchanged';

        $report->update({ external_id => 'waste-15006-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 1, 'No new update';
        is $report->state, 'investigating', 'No state change';

        $report->update({ external_id => 'waste-15004-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 2, 'A new update';
        is $report->state, 'fixed - council', 'State changed';

        FixMyStreet::Script::Alerts::send_updates();
        $mech->email_count_is(1);
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['kingston', 'sutton'],
        COBRAND_FEATURES => {
            echo => { kingston => {
                url => 'https://www.example.org/',
                receive_action => 'action',
                receive_username => 'un',
                receive_password => 'password',
            } },
            waste => { kingston => 1, sutton => 1 }
        },
    }, sub {
        my $in = $mech->echo_notify_xml('waste-15004-', 1638, 15002, '');
        my $mech2 = $mech->clone;
        $mech2->host('kingston.example.org');
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 3, 'A new update';
        $report->discard_changes;
        is $report->state, 'investigating', 'A state change';

        FixMyStreet::Script::Alerts::send_updates();
        $mech->clear_emails_ok;

        $report->update_extra_field({ name => 'Collection_Date', value => '2023-09-26T00:00:00Z' });
        $report->set_extra_metadata( item_1 => 'Armchair' );
        $report->set_extra_metadata( item_2 => 'BBQ' );
        $report->push_extra_fields( # Add extra fields expected on a Bulky waste report
            { name => 'Bulky_Collection_Bulky_Items', value => '3::85::83'}, { name => 'Bulky_Collection_Notes', value => 'One::Two::Three' }
        );
        $report->update({ category => 'Bulky collection', external_id => 'waste-15005-' });

        $in = $mech->echo_notify_xml('waste-15005-', 1636, 15005, '');
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 4, 'A new update';
        $report->discard_changes;
        is $report->state, 'closed', 'A state change';

        FixMyStreet::Script::Alerts::send_updates();
        $mech->email_count_is(0); # No email, as no payment received

        $report->set_extra_metadata( payment_reference => 'Pay123' );
        $report->update({ external_id => 'waste-with-image' });

        $in = $mech->echo_notify_xml('waste-with-image', 1638, 15004, '');
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 5, 'A new update';
        $report->discard_changes;
        is $report->state, 'fixed - council', 'A state change';
        my $update = FixMyStreet::DB->resultset("Comment")->order_by('-id')->first;
        is $update->photo, '34c2a90ba9eb225b87ca1bac05fddd0e08ac865f.jpeg';
        FixMyStreet::Script::Alerts::send_updates();
        my $body = $mech->get_email->as_string;
        my $id = $report->id;
        like $body, qr/Reference: LBS-$id/;
        like $body, qr/Armchair/;
        like $body, qr/26 September/;
        like $body, qr/Your collection has now been completed/;
        $mech->host('sutton.example.org');
        (my $token) = $body =~ m#http://sutton.example.org(/R/.*?)"#;
        $mech->get_ok($token);
        (my $photo_link_thumbnail) = $mech->content =~ m#Photo of this report" src="(/photo.*?1)"#;
        (my $photo_link_full) = $mech->content =~ m#a href="(/photo.*?1)"#;
        $mech->get_ok($photo_link_thumbnail, "Successfully call thumbnail image");
        $mech->get_ok($photo_link_full, "Successfully call full image");
    };
};

# Report here is bulky, with a date
FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'sutton',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1 },
}, sub {
    subtest 'test reservations expired by time it reaches Echo' => sub {
        $report->update_extra_field({ name => 'GUID', value => 'guid' });
        $report->update_extra_field({ name => 'property_id', value => 'prop' });
        my $sender = FixMyStreet::SendReport::Open311->new(
            bodies => [ $body ], body_config => { $body->id => $body },
        );
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('CancelReservedSlotsForEvent', sub {
            is $_[1], $report->get_extra_field_value('GUID');
        });
        $echo->mock('ReserveAvailableSlotsForEvent', sub {
            [ {
                StartDate => { OffsetMinutes => 0, DateTime => '2023-09-26T00:00:00Z' },
                Expiry => { OffsetMinutes => 0, DateTime => '2023-09-27T00:00:00Z' },
                Reference => 'NewRes',
            } ];
        });
        Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Selected reservations expired</description></error></errors>', 500);
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
        $report->discard_changes;
        is $report->get_extra_field_value('reservation'), 'NewRes';
    };
};

subtest 'Dashboard CSV export includes bulky items' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'sutton',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $staff_user = $mech->create_user_ok('staff@sutton.gov.uk', name => 'Staff User', from_body => $body);

        my ($report) = $mech->create_problems_for_body(1, $body->id, 'Bulky collection', {
            areas => "2498", category => 'Bulky collection', cobrand => 'sutton',
            user => $user, state => 'confirmed', cobrand_data => 'waste'
        });
        $report->set_extra_metadata('item_1' => 'Sofa', 'item_2' => 'Wardrobe', 'item_3' => 'Table');
        $report->update;

        $mech->log_in_ok( $staff_user->email );
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Item 1","Item 2","Item 3","Item 4","Item 5"', "Items columns added");
        $mech->content_like(qr/Bulky collection.*?Sofa,Wardrobe,Table,,/, "Items exported") or diag $mech->content;
    };
};

done_testing();
