use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(163793, 'Buckinghamshire Council', {
    send_method => 'Open311', api_key => 'key', endpoint => 'endpoint', jurisdiction => 'fms', can_be_devolved => 1 }, { cobrand => 'buckinghamshire' });
my $parish = $mech->create_body_ok(53822, 'Adstock Parish Council');
my $other_body = $mech->create_body_ok(1234, 'Some Other Council');
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
$counciluser->user_body_permissions->create({ body => $body, permission_type => 'triage' });
my $publicuser = $mech->create_user_ok('fmsuser@example.org', name => 'Simon Neil');

my $contact = $mech->create_contact_ok(body_id => $body->id, category => 'Flytipping', email => "FLY");
$contact->set_extra_fields({
    code => 'road-placement',
    datatype => 'singlevaluelist',
    description => 'Is the fly-tip located on',
    order => 100,
    required => 'true',
    variable => 'true',
    values => [
        { key => 'road', name => 'The road' },
        { key => 'off-road', name => 'Off the road/on a verge' },
    ],
});
$contact->update;
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "POT");
$mech->create_contact_ok(body_id => $body->id, category => 'Blocked drain', email => "DRA");
$mech->create_contact_ok(body_id => $body->id, category => 'Car Parks', email => "car\@chiltern", send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Graffiti', email => "graffiti\@chiltern", send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping (off-road)', email => "districts_flytipping", send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Barrier problem', email => 'parking@example.org', send_method => 'Email', group => 'Car park issue');
$mech->create_contact_ok(body_id => $body->id, category => 'Grass cutting', email => 'grass@example.org', send_method => 'Email');

# Create another Grass cutting category for a parish.
$contact = $mech->create_contact_ok(body_id => $parish->id, category => 'Grass cutting', email => 'grassparish@example.org', send_method => 'Email');
$contact->set_extra_fields({
    code => 'speed_limit_greater_than_30',
    description => 'Is the speed limit on this road 30mph or greater?',
    datatype => 'singlevaluelist',
    order => 1,
    variable => 'true',
    required => 'true',
    protected => 'false',
    values => [
        {
            key => 'yes',
            name => 'Yes',
        },
        {
            key => 'no',
            name => 'No',
        },
        {
            key => 'dont_know',
            name => "Don't know",
        },
    ],
});
$contact->update;
$contact = $mech->create_contact_ok(body_id => $parish->id, category => 'Dirty signs', email => 'signs@example.org', send_method => 'Email');

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Buckinghamshire');
$cobrand->mock('lookup_site_code', sub {
    my ($self, $row) = @_;
    return "Road ID" if $row->latitude == 51.812244;
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'buckinghamshire', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => {
        open311_email => {
            buckinghamshire => {
                flytipping => 'flytipping@example.com',
                flood => 'floods@example.org',
            }
        },
        borough_email_addresses => {
            buckinghamshire => {
                districts_flytipping => [
                    { email => "flytipping\@chiltern", areas => [ 2257 ] },
                ]
            }
        }
    }
}, sub {

subtest 'cobrand displays council name' => sub {
    ok $mech->host("buckinghamshire.fixmystreet.com"), "change host to bucks";
    $mech->get_ok('/');
    $mech->content_contains('Buckinghamshire');
};

subtest 'cobrand displays correct categories' => sub {
    my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.615559&longitude=-0.556903');
    is @{$json->{bodies}}, 2, 'Bucks and parish returned';
    like $json->{category}, qr/Car Parks/, 'Car Parks displayed';
    like $json->{category}, qr/Flytipping/, 'Flytipping displayed';
    like $json->{category}, qr/Blocked drain/, 'Blocked drain displayed';
    like $json->{category}, qr/Graffiti/, 'Graffiti displayed';
    like $json->{category}, qr/Grass cutting/, 'Grass cutting displayed';
    unlike $json->{category}, qr/Flytipping \(off-road\)/, 'Flytipping (off-road) not displayed';
    $json = $mech->get_ok_json('/report/new/category_extras?latitude=51.615559&longitude=-0.556903');
    is @{$json->{bodies}}, 2, 'Still Bucks and parish returned';
};

my ($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Flytipping', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
    dt => DateTime->now()->subtract(minutes => 10),
});

subtest 'flytipping on road sent to extra email' => sub {
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'TfB <flytipping@example.com>';
    is $email[0]->header('Reply-To'), undef, 'No reply-to header';
    like $mech->get_text_body_from_email($email[1]), qr/report's reference number/;
    $report->discard_changes;
    is $report->external_id, 248, 'Report has right external ID';
};

($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Potholes', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
    extra => {
        contributed_as => 'another_user',
        contributed_by => $counciluser->id,
    },
    dt => DateTime->now()->subtract(minutes => 9),
});

subtest 'pothole on road not sent to extra email, only confirm sent' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(1);
    like $mech->get_text_body_from_email, qr/report's reference number/;
    $report->discard_changes;
    is $report->external_id, 248, 'Report has right external ID';
};

# report made in Flytipping category off road should get moved to other category
subtest 'Flytipping not on a road gets recategorised' => sub {
    $mech->log_in_ok($publicuser->email);
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Flytipping');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Flytipping',
            'road-placement' => 'off-road',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council.');
    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->category, "Flytipping (off-road)", 'Report was recategorised correctly';
};

subtest 'Flytipping not on a road on .com gets recategorised' => sub {
    ok $mech->host("www.fixmystreet.com"), "change host to www";
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Flytipping');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Flytipping',
            'road-placement' => 'off-road',
        }
    }, "submit details");
    $mech->content_contains('on its way to the council right now');
    $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->category, "Flytipping (off-road)", 'Report was recategorised correctly';
    ok $mech->host("buckinghamshire.fixmystreet.com"), "change host to bucks";
};

subtest 'Can triage an on-road flytipping to off-road' => sub {
    $mech->log_in_ok( $counciluser->email );
    $report->update({ state => 'for triage' });
    $mech->get_ok('/admin/triage');
    $mech->content_contains('Test Report');
    $mech->get_ok('/report/' . $report->id);
    $mech->content_contains('<option value="Flytipping (off-road)"');
    $report->update({ state => 'confirmed' });
};

subtest 'Flytipping not on a road going to HE does not get recategorised' => sub {
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Flytipping');
    $mech->submit_form_ok({
        with_fields => {
            single_body_only => 'National Highways',
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Flytipping',
            'road-placement' => 'off-road',
        }
    }, "submit details");
    $mech->content_contains('We don&rsquo;t handle this type of problem');
    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->category, "Flytipping", 'Report was not recategorised';

    $mech->log_out_ok;
};

subtest 'Ex-district reports are sent to correct emails' => sub {
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(4); # (one for council, one confirmation for user) x 2
    my @email = $mech->get_email;
    is $email[0]->header('To'), '"Buckinghamshire Council" <flytipping@chiltern>';
    unlike $mech->get_text_body_from_email($email[0]), qr/If there is a/;

    like $mech->get_text_body_from_email($email[1]), qr/reference number is/;
    unlike $mech->get_text_body_from_email($email[1]), qr/please contact Buckinghamshire/;
};

my ($report2) = $mech->create_problems_for_body(1, $body->id, 'Drainage problem', {
    category => 'Blocked drain', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
    dt => DateTime->now()->subtract(minutes => 8),
});

subtest 'blocked drain sent to extra email' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), '"Flood Management" <floods@example.org>';
    like $mech->get_text_body_from_email($email[1]), qr/report's reference number/;
};

$cobrand = FixMyStreet::Cobrand::Buckinghamshire->new();

for my $test (
    {
        desc => 'filters basic emails',
        in => 'email: test@example.com',
        out => 'email: ',
    },
    {
        desc => 'filters emails in brackets',
        in => 'email: <test@example.com>',
        out => 'email: <>',
    },
    {
        desc => 'filters emails from hosts',
        in => 'email: test@mail.example.com',
        out => 'email: ',
    },
    {
        desc => 'filters multiple emails',
        in => 'email: test@example.com and user@fixmystreet.com',
        out => 'email:  and ',
    },
    {
        desc => 'filters basic phone numbers',
        in => 'number: 07700 900000',
        out => 'number: ',
    },
    {
        desc => 'filters multiple phone numbers',
        in => 'number: 07700 900000 and 07700 900001',
        out => 'number:  and ',
    },
    {
        desc => 'filters 3 part phone numbers',
        in => 'number: 0114 496 0999',
        out => 'number: ',
    },
    {
        desc => 'filters international phone numbers',
        in => 'number: +44 114 496 0999',
        out => 'number: ',
    },
    {
        desc => 'filters 020 phone numbers',
        in => 'number: 020 7946 0999',
        out => 'number: ',
    },
    {
        desc => 'filters no area phone numbers',
        in => 'number: 01632 01632',
        out => 'number: ',
    },
    {
        desc => 'does not filter normal numbers',
        in => 'number: 16320163236',
        out => 'number: 16320163236',
    },
    {
        desc => 'does not filter short numbers',
        in => 'number: 0163 1632',
        out => 'number: 0163 1632',
    },
) {
    subtest $test->{desc} => sub {
        is $cobrand->filter_report_description($test->{in}), $test->{out}, "filtered correctly";
    };
}

subtest 'extra CSV columns are present' => sub {
    $mech->log_in_ok( $counciluser->email );

    $mech->get_ok('/dashboard?export=1');

    my @rows = $mech->content_as_csv;
    is scalar @rows, 6, '1 (header) + 4 (reports) = 6 lines';
    is scalar @{$rows[0]}, 22, '22 columns present';

    is_deeply $rows[0],
        [
            'Report ID', 'Title', 'Detail', 'User Name', 'Category',
            'Created', 'Confirmed', 'Acknowledged', 'Fixed', 'Closed',
            'Status', 'Latitude', 'Longitude', 'Query', 'Ward',
            'Easting', 'Northing', 'Report URL', 'Device Type', 'Site Used',
            'Reported As', 'Staff User',
        ],
        'Column headers look correct';

    is $rows[1]->[21], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[2]->[21], $counciluser->email, 'Staff User is correct if made on behalf of another user';
    is $rows[3]->[21], '', 'Staff User is empty if not made on behalf of another user';

    $mech->create_comment_for_problem($report, $counciluser, 'Staff User', 'Some update text', 'f', 'confirmed', undef, {
        extra => { contributed_as => 'body', contributed_by => $counciluser->id }});
    $mech->create_comment_for_problem($report, $counciluser, 'Other User', 'Some update text', 'f', 'confirmed', undef, {
        extra => { contributed_as => 'another_user', contributed_by => $counciluser->id }});

    $mech->get_ok('/dashboard?export=1&updates=1');

    @rows = $mech->content_as_csv;
    is scalar @rows, 3, '1 (header) + 2 (updates)';
    is scalar @{$rows[0]}, 9, '9 columns present';
    is_deeply $rows[0],
        [
            'Report ID', 'Update ID', 'Date', 'Status', 'Problem state',
            'Text', 'User Name', 'Reported As', 'Staff User',
        ],
        'Column headers look correct';

    is $rows[1]->[8], $counciluser->email, 'Staff User is correct if made on behalf of body';
    is $rows[2]->[8], $counciluser->email, 'Staff User is correct if made on behalf of another user';
};

subtest 'old district council names are now just "areas"' => sub {

    my %points = (
       'Aylesbury Vale' => [
           [ 51.822364, -0.826409 ], # AVDC offices
           [ 51.995, -0.986 ], # Buckingham
           [ 51.940, -0.887 ], # Winslow
       ],
        'Chiltern' => [
           [ 51.615559, -0.556903, ],
        ],
        'South Bucks' => [
            [ 51.563, -0.499 ], # Denham
            [ 51.611, -0.644 ], # Beaconsfield Railway Station
        ],
         'Wycombe' => [
             [ 51.628661, -0.748238 ], # High Wycombe
             [ 51.566667, -0.766667 ], # Marlow
         ],
    );

    for my $area (sort keys %points) {
        for my $loc (@{$points{$area}}) {
            $mech->get("/alert/list?latitude=$loc->[0];longitude=$loc->[1]");
            $mech->content_contains("$area area");
            $mech->content_lacks("$area District Council");
            $mech->content_lacks("ward, $area District Council");
            $mech->content_lacks('County Council');
            $mech->content_contains('Buckinghamshire Council');
        }
    }

};

my $bucks = Test::MockModule->new('FixMyStreet::Cobrand::Buckinghamshire');

subtest 'Prevents car park reports being made outside a car park' => sub {
    # Simulate no car parks found
    $bucks->mock('_get', sub { "<wfs:FeatureCollection></wfs:FeatureCollection>" });

    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Barrier+problem');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Barrier problem',
        }
    }, "submit details");
    $mech->content_contains('Please select a location in a Buckinghamshire maintained car park') or diag $mech->content;
};

subtest 'Allows car park reports to be made in a car park' => sub {
    # Now simulate a car park being found
    $bucks->mock('_get', sub {
        "<wfs:FeatureCollection>
            <gml:featureMember>
                <Transport_BC_Car_Parks:BC_CAR_PARKS>
                    <Transport_BC_Car_Parks:OBJECTID>1</Transport_BC_Car_Parks:OBJECTID>
                </Transport_BC_Car_Parks:BC_CAR_PARKS>
            </gml:featureMember>
        </wfs:FeatureCollection>"
    });

    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Barrier+problem');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Barrier problem',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');
};

subtest 'sends grass cutting reports on roads under 30mph to the parish' => sub {
    FixMyStreet::Script::Reports::send();
    $mech->clear_emails_ok;
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Grass+cutting');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test grass cutting report 1",
            detail => 'Test report details.',
            category => 'Grass cutting',
            speed_limit_greater_than_30 => 'no', # Is the speed limit greater than 30mph?
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');
    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->title, 'Test grass cutting report 1', 'Got the correct report';
    is $report->bodies_str, $parish->id, 'Report was sent to parish';
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    like $mech->get_text_body_from_email($email[1]), qr/please contact Adstock Parish Council at grassparish\@example.org/;
};

subtest 'sends grass cutting reports on roads 30mph or more to the council' => sub {
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Grass+cutting');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test grass cutting report 2",
            detail => 'Test report details.',
            category => 'Grass cutting',
            speed_limit_greater_than_30 => 'yes', # Is the speed limit greater than 30mph?
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');
    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->title, 'Test grass cutting report 2', 'Got the correct report';
    is $report->bodies_str, $body->id, 'Report was sent to council';
};

subtest 'treats problems sent to parishes as owned by Bucks' => sub {
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Dirty signs report",
            detail => 'Test report details.',
            category => 'Dirty signs',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');

    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->title, 'Test Dirty signs report', 'Got the correct report';

    # Check that the report can be accessed via the cobrand
    my $report_id = $report->id;
    $mech->get_ok("/report/$report_id");
};

subtest 'body filter on dashboard' => sub {
    $mech->get_ok('/dashboard');
    $mech->content_contains('<h1>' . $body->name . '</h1>', 'defaults to Bucks');
    $mech->content_contains('<select class="form-control" name="body" id="body">', 'extra bodies dropdown is shown');
    $mech->content_contains('<option value="' . $body->id . '">' . $body->name . '</option>', 'Bucks is shown in the options');
    $mech->content_contains('<option value="' . $parish->id . '">' . $parish->name . '</option>', 'parish is shown in the options');

    $mech->get_ok('/dashboard?body=' . $parish->id);
    $mech->content_contains('<h1>' . $parish->name . '</h1>', 'shows parish dashboard');

    $mech->get_ok('/dashboard?body=' . $other_body->id);
    $mech->content_contains('<h1>' . $body->name . '</h1>', 'defaults to Bucks when body is not permitted');
};

subtest 'All reports pages for parishes' => sub {
    $mech->get_ok('/reports/Buckinghamshire');
    $mech->content_contains('View reports sent to Parish/Town Councils');

    $mech->get_ok('/about/parishes');
    $mech->content_contains('Adstock Parish Council');

    $mech->get_ok('/reports/Adstock');
    $mech->content_contains('Adstock Parish Council');
    is $mech->uri->path, '/reports/Adstock';
};

subtest 'Reports to parishes are closed by default' => sub {
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Dirty signs report 2",
            detail => 'Test report details.',
            category => 'Dirty signs',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');

    FixMyStreet::Script::Reports::send();

    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->title, 'Test Dirty signs report 2', 'Got the correct report';
    is $report->state, 'internal referral', 'parish report is automatically marked as closed';
};

};

done_testing();
