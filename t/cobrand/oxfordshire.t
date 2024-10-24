use Test::MockModule;

use CGI::Simple;
use File::Temp 'tempdir';
use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Reports;
use Open311;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council', { cobrand => 'oxfordshire' });
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxon);
my $role = FixMyStreet::DB->resultset("Role")->create({ body => $oxon, name => 'Role', permissions => [] });
$counciluser->add_to_roles($role);
my $user = $mech->create_user_ok( 'user@example.com', name => 'Test User' );
my $user2 = $mech->create_user_ok( 'user2@example.com', name => 'Test User2' );

my $oxfordshire_cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Oxfordshire');
$oxfordshire_cobrand->mock('area_types', sub { [ 'CTY' ] });

$oxfordshire_cobrand->mock('get', sub {
    return '{
        "features": [
            {
                "properties": {
                    "APPROVAL_STATUS_NAME": "With Contractor",
                    "ITEM_CATEGORY_NAME": "Minor Carriageway",
                    "ITEM_TYPE_NAME": "Pothole",
                    "REQUIRED_COMPLETION_DATE": "2020-11-05T16:41:00Z"
                },
                "geometry": {
                    "coordinates": [-1.3553, 51.8477]
                }
            },
            {
                "properties": {
                    "APPROVAL_STATUS_NAME": "With Contractor",
                    "ITEM_CATEGORY_NAME": "Trees and Hedges",
                    "ITEM_TYPE_NAME": "Overgrown/Overhanging",
                    "REQUIRED_COMPLETION_DATE": "2020-11-05T16:41:00Z"
                },
                "geometry": {
                    "coordinates": [-1.3554, 51.8478]
                }
            }
        ]
    }';
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
    COBRAND_FEATURES => {
        public_asset_ids =>
            { oxfordshire => [ 'feature_id', 'unit_number' ] },
    },
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
    my %cobrands = ( oxfordshire => 'oxfordshire.fixmystreet.com', fixmystreet => 'www.fixmystreet.com' );
    for my $cobrand ( keys %cobrands ) {
        my $host = $cobrands{$cobrand};
        ok $mech->host($host);

        subtest "$host handles external IDs/refs correctly" => sub {
            $mech->get_ok('/report/' . $problem1->id);
            $mech->content_lacks($problem1->external_id, "WDM external ID not shown");
            $mech->content_contains('Council ref:</strong> ENQ12098123', "WDM customer reference is shown");
            $mech->content_contains('Asset ID:</strong> 123', "Asset ID is shown");

            $mech->get_ok('/report/' . $problem2->id);
            $mech->content_lacks($problem2->external_id, "Alloy external ID not shown");
            $mech->content_contains('Council ref:</strong> ' . $problem2->id, "FMS id is shown");
            $mech->content_contains('Asset ID:</strong> 456', "Asset ID is shown");
        };

        subtest "check unable to fix label on $host" => sub {
            my $problem = $problems[0];
            $problem->state( 'unable to fix' );
            $problem->update;

            my $alert = FixMyStreet::DB->resultset('Alert')->find_or_create( {
                parameter  => $problem->id,
                alert_type => 'new_updates',
                user       => $user,
            } );
            $alert->confirm;
            $alert->update({ cobrand => $cobrand });

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

            if ($cobrand eq 'oxfordshire') {
                $mech->get_ok('/reports/Oxfordshire?ajax=1&status=closed');
                $mech->content_contains('Investigation complete');
            }

            FixMyStreet::Script::Alerts::send_updates();
            $mech->email_count_is(1);
            my $email = $mech->get_email;
            my $body = $mech->get_text_body_from_email($email);
            like $body, qr/Investigation complete/, 'state correct in email';
            if ($cobrand eq 'oxfordshire') {
                like $body, qr/fix every issue reported on FixMyStreet/;
            }
            $mech->clear_emails_ok;
        };
    };

    # Reset for the rest of the tests
    ok $mech->host('oxfordshire.fixmystreet.com');
};

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
FixMyStreet::override_config {
    STAGING_FLAGS => { send_reports => 1, skip_checks => 1 },
    ALLOWED_COBRANDS => 'oxfordshire',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
}, sub {

    subtest 'can use customer reference to search for reports' => sub {
        my $problem = $problems[0];
        $problem->set_extra_metadata( customer_reference => 'ENQ12456' );
        $problem->update;

        $mech->get_ok('/around?pc=ENQ12456');
        is $mech->uri->path, '/report/' . $problem->id, 'redirects to report';
    };

    subtest 'extra CSV columns are present' => sub {

        $problems[1]->update_extra_field({ name => 'usrn', value => '20202020' });
        $problems[1]->set_extra_metadata(contributed_by => $counciluser->id);
        $problems[1]->update({ external_id => $problems[1]->id });
        $problems[2]->update({ external_id => "123098123" });

        $mech->log_in_ok( $counciluser->email );

        $mech->get_ok('/dashboard?export=1');

        my @rows = $mech->content_as_csv;
        is scalar @rows, 7, '1 (header) + 6 (reports) = 7 lines';
        is scalar @{$rows[0]}, 24, '24 columns present';

        is_deeply $rows[0],
            [
                'Report ID', 'Title', 'Detail', 'User Name', 'Category',
                'Created', 'Confirmed', 'Acknowledged', 'Fixed', 'Closed',
                'Status', 'Latitude', 'Longitude', 'Query', 'Ward',
                'Easting', 'Northing', 'Report URL', 'Device Type', 'Site Used',
                'Reported As', 'HIAMS/Exor Ref', 'USRN', 'Staff Role'
            ],
            'Column headers look correct';

        is $rows[1]->[21], 'ENQ12456', 'HIAMS reference included in row';
        is $rows[1]->[22], '', 'Report without USRN has empty usrn field';
        is $rows[2]->[21], '', 'Report without HIAMS ref has empty ref field';
        is $rows[2]->[22], '20202020', 'USRN included in row if present';
        is $rows[2]->[23], 'Role', 'Correct staff role';
        is $rows[3]->[21], '123098123', 'Older Exor report has correct ref';
    };

    subtest 'extra update CSV columns are present' => sub {

        my $comment = $problems[1]->add_to_comments({
            text => 'Test update',
            user => $counciluser,
            send_state => 'processed',
            extra => {
                contributed_by => $counciluser->id,
            }
        });

        $mech->get_ok('/dashboard?export=1&updates=1');

        my @rows = $mech->content_as_csv;
        is scalar @rows, 4, '1 (header) + 3 (updates) = 4 lines';
        is scalar @{$rows[0]}, 9, '9 columns present';

        is_deeply $rows[0],
            [
                'Report ID',
                'Update ID',
                'Date',
                'Status',
                'Problem state',
                'Text',
                'User Name',
                'Reported As',
                'Staff Role',
            ],
            'Column headers look correct';

        is $rows[3]->[8], 'Role', 'Correct role in output';
        $comment->delete;
    };

    subtest 'role filter works okay pre-generated' => sub {
        $problems[1]->set_extra_metadata(contributed_by => $counciluser->id);
        $problems[1]->confirmed('2022-05-05T12:00:00');
        $problems[1]->update;
        $problems[2]->set_extra_metadata(contributed_by => $counciluser->id);
        $problems[2]->confirmed('2022-05-05T12:00:00');
        $problems[2]->update;
        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1&start_date=2022-01-01&role=' . $role->id);
        my @rows = $mech->content_as_csv;
        is scalar @rows, 3, '1 (header) + 2 (reports) = 3 lines';
        $mech->get_ok('/dashboard?export=1&start_date=2022-1-1&end_date=2022-12-31');
        @rows = $mech->content_as_csv;
        is scalar @rows, 3, 'Bad start date parsed okay, both results from 2022 returned';
        $mech->get_ok('/dashboard?export=1&start_date=2022-01-01&end_date=2022-05-05');
        @rows = $mech->content_as_csv;
        is scalar @rows, 3, 'Exact end date parsed okay, both results from 2022 returned';
    };

    $oxon->update({
        send_method => 'Open311',
        endpoint => 'endpoint',
        api_key => 'key',
        jurisdiction => 'home',
    });
    my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Gullies and Catchpits', email => 'Alloy-GC' );
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
                extra => { contributed_by => $counciluser->id },
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
            is $c->param('attribute[staff_role]'), 'Role';
        };
    }

    subtest 'extra data sent with defect update' => sub {
        my $wh = $mech->create_body_ok(2417, 'Vale of White Horse');
        my $comment = FixMyStreet::DB->resultset('Comment')->first;
        $mech->create_contact_ok(body_id => $wh->id, category => $comment->problem->category, email => 'whemail@example.org');
        $comment->set_extra_metadata(defect_raised => 1);
        $comment->update;
        $comment->problem->external_id('hey');
        $comment->problem->bodies_str($wh->id . ',' . $comment->problem->bodies_str);
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
        is $cgi->param('service_code'), $comment->problem->category;

        # Now set a USRN on the problem (found at submission)
        $comment->problem->push_extra_fields({ name => 'usrn', value => '12345' });
        $comment->problem->update;

        $o->post_service_request_update($comment);
        $cgi = CGI::Simple->new($o->test_req_used->content);
        is $cgi->param('attribute[usrn]'), 12345, 'USRN sent with update';
        is $cgi->param('attribute[raise_defect]'), 1, 'Defect flag sent with update';
    };

    subtest 'street lighting duplicates' => sub {
        my $latitude = 51.784721;
        my $longitude = -1.494453;
        $mech->create_contact_ok( body_id => $oxon->id, category => 'Lamp out', email => 'streetlighting', group => 'Street Lighting' );
        $mech->create_contact_ok( body_id => $oxon->id, category => 'Lamp on all day', email => 'streetlighting', group => 'Street Lighting' );
        $mech->create_contact_ok( body_id => $oxon->id, category => 'Lamp leaning', email => 'streetlighting', group => 'Street Lighting' );
        my @params = (1, $oxon->id, 'Other light', { latitude => $latitude, longitude => $longitude, category => 'Lamp on all day', cobrand => 'oxfordshire' });
        $mech->create_problems_for_body(@params);
        $params[3]{category} = 'Lamp leaning';
        $mech->create_problems_for_body(@params);
        my $json = $mech->get_ok_json("/around/nearby?latitude=$latitude&longitude=$longitude&filter_category=Lamp+out");
        my $pins = $json->{pins};
        is scalar @$pins, 2, 'other street lighting pins included';
    };

    subtest "Sends FMS report ID in confirmation emails when user is logged in." => sub {
        FixMyStreet::Script::Reports::send();
        $mech->clear_emails_ok;

        my ($report) = $mech->create_problems_for_body( 1, $oxon->id, 'Flooded Gully', {
            cobrand => 'oxfordshire',
            category => 'Gullies and Catchpits',
            user => $user,
            latitude => 51.754926,
            longitude => -1.256179,
        });

        FixMyStreet::Script::Reports::send();

        my $email = $mech->get_email; # tests that there's precisely 1 email in queue
        my $email_text = $mech->get_text_body_from_email($email);
        like $email_text, qr/Your report to Oxfordshire County Council has been logged/, "A confirmation email has been received from Oxfordshire CC";
        like $email_text, qr/The report's reference number is \d+\./, "...with a numerical case ref. in the text part...";
        my $html_body = $mech->get_html_body_from_email($email);
        like $html_body, qr/The report's reference number is <strong>\d+/, "...and a numerical case ref. in the HTML part";

        $mech->clear_emails_ok;
    };

};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'oxfordshire',
    COBRAND_FEATURES => { sub_ward_reporting => { oxfordshire => ['DIW', 'CPC'] }},
    MAPIT_URL => 'http://mapit.uk/',

}, sub {
    subtest 'Shows choice of wards, parishes, divisions' => sub {
        $mech->get_ok('/reports');
        $mech->content_contains('id="key-tool-parish"', "Tabs available for districts and wards");
        $mech->content_contains('<a class="js-ward-single" href="http://oxfordshire.fixmystreet.com/reports/Oxfordshire/Faringdon?type=DIW">Faringdon</a>', "Ward list populated");
        $mech->content_contains('<a class="js-ward-single" href="http://oxfordshire.fixmystreet.com/reports/Oxfordshire/Aston+Upthorpe?type=CPC">Aston Upthorpe</a>', "Parish list populated");
        $mech->content_contains('<a class="js-ward-single" href="http://oxfordshire.fixmystreet.com/reports/Oxfordshire/South+Oxfordshire?type=DIS">South Oxfordshire District Council</a>', "District list populated");
    };

    subtest 'Shows Chinnor parish and updates rss link text to "parish"' => sub {
        $mech->get_ok('/reports/Oxfordshire/Chinnor?type=CPC', 'Report page called with parish type to differentiate area');
        $mech->content_contains('Get updates of parish problems', "rss link updated to say 'parish'");
        $mech->content_contains('Chinnor', "Link leads to Chinnor reports list");
        $mech->content_contains('/rss/reports/Oxfordshire/Chinnor?type=CPC', 'rss link contains parish type information');
    };

    subtest 'Shows Chinnor ward and leaves rss link text as "ward"' => sub {
        $mech->get_ok('/reports/Oxfordshire/Chinnor?type=DIW', 'Report page called with ward type to differentiate area');
        $mech->content_contains('Get updates of ward problems', "rss link left as 'ward'");
        $mech->content_contains('Chinnor', "Link leads to Chinnor reports list");
        $mech->content_contains('/rss/reports/Oxfordshire/Chinnor?type=DIW', 'rss link contains ward type information');
    };

    subtest 'Shows multiple wards' => sub {
        $mech->get_ok('/reports/Oxfordshire/ward=Abingdon+Abbey+Northcourt&ward=Abingdon+Caldecott?type=DIW');
        $mech->content_contains('Abingdon Abbey Northcourt', "report page contains Abingdon Abbey Northcourt reports list");
        $mech->content_contains('Abingdon Caldecott', "report page contains Abingdon Caldecott reports list");
        # TODO Mutiple wards or parishes etc default to whole council for rss
        # $mech->content_contains('Get updates of ward problems', "rss link updated to say ward");
    };

    subtest 'rss updates "ward" text to "parish" for Adwell parish' => sub {
        $mech->get_ok('/rss/reports/Oxfordshire/Adwell?type=CPC');
        $mech->content_contains('within Adwell parish', 'Text updated from ward to parish on rss page');
        $mech->content_contains('<uri>http://oxfordshire.fixmystreet.com/rss/reports/Oxfordshire/Adwell?type=CPC</uri>', 'url to copy contains parish type information');
    };
};

done_testing();
