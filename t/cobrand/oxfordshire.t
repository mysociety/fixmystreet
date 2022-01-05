use Test::MockModule;

use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;
use Open311;
my $mech = FixMyStreet::TestMech->new;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxon);

my $oxfordshire_cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Oxfordshire');

$oxfordshire_cobrand->mock('defect_wfs_query', sub {
    return {
        features => [
            {
                properties => {
                    APPROVAL_STATUS_NAME => 'With Contractor',
                    ITEM_CATEGORY_NAME => 'Minor Carriageway',
                    ITEM_TYPE_NAME => 'Pothole',
                    REQUIRED_COMPLETION_DATE => '2020-11-05T16:41:00Z',
                },
                geometry => {
                    coordinates => [-1.3553, 51.8477],
                }
            },
            {
                properties => {
                    APPROVAL_STATUS_NAME => 'With Contractor',
                    ITEM_CATEGORY_NAME => 'Trees and Hedges',
                    ITEM_TYPE_NAME => 'Overgrown/Overhanging',
                    REQUIRED_COMPLETION_DATE => '2020-11-05T16:41:00Z',
                },
                geometry => {
                    coordinates => [-1.3554, 51.8478],
                }
            }
        ]
    };
});

subtest 'check /around?ajax gets extra pins from wfs' => sub {
    $mech->delete_problems_for_body($oxon->id);

    my $latitude = 51.784721;
    my $longitude = -1.494453;
    my $bbox = ($longitude - 0.01) . ',' .  ($latitude - 0.01)
                . ',' . ($longitude + 0.01) . ',' .  ($latitude + 0.01);

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
    }, sub {
        my $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 2, 'defect pins included';
        my $pin = @$pins[0];
        is @$pin[4], "Minor Carriageway (Pothole)\nEstimated completion date: Thursday  5 November 2020", 'pin title is correct';
    }
};

subtest 'check /around/nearby gets extra pins from wfs' => sub {
    $mech->delete_problems_for_body($oxon->id);

    my $latitude = 51.784721;
    my $longitude = -1.494453;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
    }, sub {
        my $json = $mech->get_ok_json( "/around/nearby?filter_category=Potholes&distance=250&latitude=$latitude&longitude=$longitude" );
        my $pins = $json->{pins};
        is scalar @$pins, 2, 'defect pins included';
        my $pin = @$pins[0];
        is @$pin[4], "Minor Carriageway (Pothole)\nEstimated completion date: Thursday  5 November 2020", 'pin title is correct';
    }
};

subtest 'check /reports/Oxfordshire?ajax gets extra pins from wfs for zoom 15' => sub {
    $mech->delete_problems_for_body($oxon->id);

    my $latitude = 51.784721;
    my $longitude = -1.494453;
    my $bbox = ($longitude - 0.01) . ',' .  ($latitude - 0.01)
                . ',' . ($longitude + 0.01) . ',' .  ($latitude + 0.01);

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
    }, sub {
        my $json = $mech->get_ok_json( '/reports/Oxfordshire?ajax=1&zoom=15&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 2, 'defect pins included';
        my $pin = @$pins[0];
        is @$pin[4], "Minor Carriageway (Pothole)\nEstimated completion date: Thursday  5 November 2020", 'pin title is correct';
    }
};

subtest "check /reports/Oxfordshire?ajax doesn't get extra pins from wfs at zoom 14" => sub {
    $mech->delete_problems_for_body($oxon->id);

    my $latitude = 51.784721;
    my $longitude = -1.494453;
    my $bbox = ($longitude - 0.01) . ',' .  ($latitude - 0.01)
                . ',' . ($longitude + 0.01) . ',' .  ($latitude + 0.01);

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
    }, sub {
        my $json = $mech->get_ok_json( '/reports/Oxfordshire?ajax=1&zoom=14&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 0, 'defect pins not included';
    }
};

$oxfordshire_cobrand->mock('defect_wfs_query', sub { return { features => [] }; });

subtest 'check /around?ajax defaults to open reports only' => sub {
    my $categories = [ 'Bridges', 'Fences', 'Manhole' ];
    my $params = {
        postcode  => 'OX28 4DS',
        cobrand => 'oxfordshire',
        latitude  =>  51.784721,
        longitude => -1.494453,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    # Create one open and one fixed report in each category
    foreach my $category ( @$categories ) {
        foreach my $state ( 'confirmed', 'fixed' ) {
            my %report_params = (
                %$params,
                category => $category,
                state => $state,
            );
            $mech->create_problems_for_body( 1, $oxon->id, 'Around page', \%report_params );
        }
    }

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
    }, sub {
        my $json = $mech->get_ok_json( '/around?ajax=1&status=all&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 6, 'correct number of reports created';

        $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 3, 'correct number of reports returned with no filters';

        $json = $mech->get_ok_json( '/around?ajax=1&filter_category=Fences&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 1, 'only one Fences report by default';
    }
};

my @problems = FixMyStreet::DB->resultset('Problem')->search({}, { rows => 3, order_by => 'id' })->all;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'oxfordshire', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

    my $problem1 = $problems[0];
    $problem1->external_id("132987");
    $problem1->set_extra_metadata(customer_reference => "ENQ12098123");
    $problem1->update_extra_field({ name => "feature_id", "value" => "123" });
    $problem1->whensent($problem1->confirmed);
    $problem1->update;
    my $problem2 = $problems[1];
    $problem2->update_extra_field({ name => "unit_number", "value" => "456" });
    $problem2->update({ external_id => "AlloyV2-687000682500b7000a1f3006", whensent => $problem2->confirmed });

    # reports should display the same info on both cobrands
    for my $host ( 'oxfordshire.fixmystreet.com', 'www.fixmystreet.com' ) {

        subtest "$host handles external IDs/refs correctly" => sub {
            ok $mech->host($host);

            $mech->get_ok('/report/' . $problem1->id);
            $mech->content_lacks($problem1->external_id, "WDM external ID not shown");
            $mech->content_contains('Council ref:</strong> ENQ12098123', "WDM customer reference is shown");
            $mech->content_contains('Asset ID:</strong> 123', "Asset ID is shown");

            $mech->get_ok('/report/' . $problem2->id);
            $mech->content_lacks($problem2->external_id, "Alloy external ID not shown");
            $mech->content_contains('Council ref:</strong> ' . $problem2->id, "FMS id is shown");
            $mech->content_contains('Asset ID:</strong> 456', "Asset ID is shown");
        };
    }

    # Reset for the rest of the tests
    ok $mech->host('oxfordshire.fixmystreet.com');
};

FixMyStreet::override_config {
    STAGING_FLAGS => { send_reports => 1, skip_checks => 1 },
    ALLOWED_COBRANDS => 'oxfordshire',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

    subtest 'can use customer reference to search for reports' => sub {
        my $problem = $problems[0];
        $problem->set_extra_metadata( customer_reference => 'ENQ12456' );
        $problem->update;

        $mech->get_ok('/around?pc=ENQ12456');
        is $mech->uri->path, '/report/' . $problem->id, 'redirects to report';
    };

    my $user = $mech->create_user_ok( 'user@example.com', name => 'Test User' );
    my $user2 = $mech->create_user_ok( 'user2@example.com', name => 'Test User2' );

    subtest 'check unable to fix label' => sub {
        my $problem = $problems[0];
        $problem->state( 'unable to fix' );
        $problem->update;

        my $alert = FixMyStreet::DB->resultset('Alert')->create( {
            parameter  => $problem->id,
            alert_type => 'new_updates',
            cobrand    => 'oxfordshire',
            user       => $user,
        } )->confirm;

        FixMyStreet::DB->resultset('Comment')->create( {
            problem_state => 'unable to fix',
            problem_id => $problem->id,
            user_id    => $user2->id,
            name       => 'User',
            mark_fixed => 'f',
            text       => "this is an update",
            state      => 'confirmed',
            confirmed  => 'now()',
            anonymous  => 'f',
        } );


        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('Investigation complete');

        FixMyStreet::Script::Alerts::send_updates();
        $mech->email_count_is(1);
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Investigation complete/, 'state correct in email';
    };

    subtest 'extra CSV columns are present' => sub {

        $problems[1]->update({ external_id => $problems[1]->id });
        $problems[2]->update({ external_id => "123098123" });

        $mech->log_in_ok( $counciluser->email );

        $mech->get_ok('/dashboard?export=1');

        my @rows = $mech->content_as_csv;
        is scalar @rows, 7, '1 (header) + 6 (reports) = 7 lines';
        is scalar @{$rows[0]}, 22, '22 columns present';

        is_deeply $rows[0],
            [
                'Report ID', 'Title', 'Detail', 'User Name', 'Category',
                'Created', 'Confirmed', 'Acknowledged', 'Fixed', 'Closed',
                'Status', 'Latitude', 'Longitude', 'Query', 'Ward',
                'Easting', 'Northing', 'Report URL', 'Device Type', 'Site Used',
                'Reported As', 'HIAMS/Exor Ref',
            ],
            'Column headers look correct';

        is $rows[1]->[21], 'ENQ12456', 'HIAMS reference included in row';
        is $rows[2]->[21], '', 'Report without HIAMS ref has empty ref field';
        is $rows[3]->[21], '123098123', 'Older Exor report has correct ref';
    };

    $oxon->update({
        send_method => 'Open311',
        endpoint => 'endpoint',
        api_key => 'key',
        jurisdiction => 'home',
    });
    my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Gullies and Catchpits', email => 'GC' );
    $contact->set_extra_fields( (
        { code => 'feature_id', datatype => 'hidden', variable => 'true' },
        { code => 'usrn', datatype => 'hidden', variable => 'true' },
    ) );
    $contact->update;
    FixMyStreet::Script::Reports::send(); # Make sure no waiting reports

    for my $test (
        {
            field => 'feature_id',
            value => '12345',
            text => 'Asset Id',
        },
    ) {
        subtest 'Check special Open311 request handling of ' . $test->{text}, sub {
            my ($p) = $mech->create_problems_for_body( 1, $oxon->id, 'Test', {
                cobrand => 'oxfordshire',
                category => 'Gullies and Catchpits',
                user => $user,
                latitude => 51.754926,
                longitude => -1.256179,
            });
            $p->set_extra_fields({ name => $test->{field}, value => $test->{value}});
            $p->update;

            FixMyStreet::Script::Reports::send();

            $p->discard_changes;
            ok $p->whensent, 'Report marked as sent';
            is $p->send_method_used, 'Open311', 'Report sent via Open311';
            is $p->external_id, 248, 'Report has right external ID';
            unlike $p->detail, qr/$test->{text}:/, $test->{text} . ' not saved to report detail';

            my $req = Open311->test_req_used;
            my $c = CGI::Simple->new($req->content);
            like $c->param('description'), qr/$test->{text}: $test->{value}/, $test->{text} . ' included in body';
        };
    }

    subtest 'extra data sent with defect update' => sub {
        my $comment = FixMyStreet::DB->resultset('Comment')->first;
        $comment->set_extra_metadata(defect_raised => 1);
        $comment->update;
        $comment->problem->external_id('hey');
        $comment->problem->set_extra_metadata(defect_location_description => 'Location');
        $comment->problem->set_extra_metadata(defect_item_category => 'Kerbing');
        $comment->problem->set_extra_metadata(defect_item_type => 'Damaged');
        $comment->problem->set_extra_metadata(defect_item_detail => '1 kerb unit or 1 linear m');
        $comment->problem->set_extra_metadata(traffic_information => 'Signs and Cones');
        $comment->problem->set_extra_metadata(detailed_information => '100x100');
        $comment->problem->update;

        $mech->create_contact_ok( body_id => $oxon->id, category => $comment->problem->category, email => $comment->problem->category );

        my $cbr = Test::MockModule->new('FixMyStreet::Cobrand::Oxfordshire');
        $cbr->mock('_fetch_features', sub {
            my ($self, $cfg, $x, $y) = @_;
            [ {
                type => 'Feature',
                geometry => { type => 'LineString', coordinates => [ [ 1, 2 ], [ 3, 4 ] ] },
                properties => { TYPE1_2_USRN => 13579 },
            } ];
        });
        my $test_res = '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>';

        my $o = Open311->new(
            fixmystreet_body => $oxon,
        );
        Open311->_inject_response('/servicerequestupdates.xml', $test_res);

        $o->post_service_request_update($comment);
        my $cgi = CGI::Simple->new($o->test_req_used->content);
        is $cgi->param('attribute[usrn]'), 13579, 'USRN sent with update';
        is $cgi->param('attribute[raise_defect]'), 1, 'Defect flag sent with update';
        is $cgi->param('attribute[defect_item_category]'), 'Kerbing';
        is $cgi->param('attribute[extra_details]'), $user2->email . ' TM1 Damaged 100x100';

        # Now set a USRN on the problem (found at submission)
        $comment->problem->push_extra_fields({ name => 'usrn', value => '12345' });
        $comment->problem->update;

        $o->post_service_request_update($comment);
        $cgi = CGI::Simple->new($o->test_req_used->content);
        is $cgi->param('attribute[usrn]'), 12345, 'USRN sent with update';
        is $cgi->param('attribute[raise_defect]'), 1, 'Defect flag sent with update';
    };

};

done_testing();
