use FixMyStreet::TestMech;
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Reports;
use File::Temp 'tempdir';
use Test::MockModule;
use CGI::Simple;
use Test::LongString;
use Open311::PostServiceRequestUpdates;
use t::Mock::Nominatim;
use FixMyStreet::Script::UsersInRoleAndBoundary;
use MIME::Base64;
use Path::Tiny;

sub mock_fetch_features {
    my ($self, $args, $x, $y) = @_;
    if ( $args->{type} && $args->{type} eq 'arcgis' ) {
        # council land
        if ( ($x == 552617 || $x == 519240) && $args->{url} =~ m{4/query} ) {
            return [ { geometry => { type => 'Point' } } ];
        } elsif ( $x == 552684 && $args->{url} =~ m{4/query} ) {
            return [ { geometry => { type => 'Point' } } ];
        } elsif ( $x == 552684 && $args->{url} =~ m{9/query} ) {
            return [ { geometry => { type => 'Polygon' } } ];
        # leased out council land
        } elsif ( $x == 552651 && $args->{url} =~ m{3/query} ) {
            return [ { geometry => { type => 'Point' } } ];
        # adopted roads
        } elsif ( $x == 552721 && $args->{url} =~ m{7/query} ) {
            return [ { geometry => { type => 'Point' } } ];
        } elsif ( $x == 551973 && $args->{url} =~ m{7/query} ) {
            # site_code lookup test
            return [ { geometry => { type => 'Polygon', coordinates => [ [ [ 551975, 298244 ], [ 551975, 298244 ] ] ] }, properties => { USRN => "ROAD" } } ];
        }
        return [];
    }
    return [];
}
my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
$mock->mock('_fetch_features', \&mock_fetch_features);

my $mech = FixMyStreet::TestMech->new;

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => 'http://endpoint.example.org',
    jurisdiction => 'home',
    can_be_devolved => 1,
    cobrand => 'peterborough',
};
my $peterborough = $mech->create_body_ok(2566, 'Peterborough City Council', $params);
my $flytipping = $mech->create_contact_ok(email => 'FLY', body_id => $peterborough->id, category => 'General fly tipping', extra => {
    _fields => [
        {"code" => "Land_Type", "order" => 17, "values" => [
            {"key" => "Back Alley - L03", "name" => "Back Alley"},
            {"key" => "Footpath / Bridleway - L02", "name" => "Footpath / Bridleway"},
            {"key" => "Highway - L01", "name" => "Highway"},
        ], "datatype" => "singlevaluelist", "required" => "true", "variable" => "true", "description" => "Land Type"},

        {"code" => "Primary_Waste_Type", "order" => 18, "values" => [
            {"key" => "Tyres - W06", "name" => "Tyres"},
            {"key" => "Vehicle Parts - W03", "name" => "Vehicle Parts"},
            {"key" => "White Goods - W04", "name" => "White Goods"},
        ], "datatype" => "singlevaluelist", "required" => "true", "variable" => "true", "description" => "Primary Waste Type"},

        {"code" => "Incident_Size", "order" => 19, "values" => [
            {"key" => "Car Boot Load or Less - S02", "name" => "Car Boot Load or Less"},
            {"key" => "Single Black Bag - S00", "name" => "Single Black Bag"},
            {"key" => "Small Van Load - S03", "name" => "Small Van Load"},
        ], "datatype" => "singlevaluelist", "required" => "true", "variable" => "true", "description" => "Incident Size"},
        {"code" => "pcc-witness", "order" => 20, "values" => [
            {"key" => "yes", "name" => "Yes"},
            {"key" => "no", "name" => "No"}
        ], "datatype" => "singlevaluelist", "required" => "true", "variable" => "true", "description" => "Did you witness the fly-tipping or have evidence about who did it?"},
    ],
});
$mech->create_contact_ok(email => 'Bartec-Sharps', body_id => $peterborough->id, category => 'Sharps');
$mech->create_contact_ok(email => 'Bartec-Graffiti', body_id => $peterborough->id, category => 'Non offensive graffiti');
my $user = $mech->create_user_ok('peterborough@example.org', name => 'Council User', from_body => $peterborough);
$peterborough->update( { comment_user_id => $user->id } );

my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $peterborough);
$staffuser->user_body_permissions->create({ body => $peterborough, permission_type => 'report_inspect' });
$staffuser->user_body_permissions->create({ body => $peterborough, permission_type => 'view_dashboard' });

my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $peterborough,
    name => 'Test Users',
    permissions => ['contribute_as_body'],
});
my $second_role = FixMyStreet::DB->resultset("Role")->create({
    body => $peterborough,
    name => 'Editor',
    permissions => ['report_edit'],
});

my $trusteduser = $mech->create_user_ok('trusteduser@example.com', name => 'Trusted User', from_body => $peterborough);
$trusteduser->user_roles->find_or_create({ role_id => $role->id });
my $multiple_roles_user = $mech->create_user_ok('multipleuser@example.com', name => 'Multiple User', from_body => $peterborough);
$multiple_roles_user->user_roles->find_or_create({ role_id => $second_role->id });
$multiple_roles_user->user_roles->find_or_create({ role_id => $role->id });


path('web/static/temp', "geo.txt")->spew([&_geodata]);

sub _trigger_sending_report {
    $mech->clear_emails_ok;
    FixMyStreet::Script::UsersInRoleAndBoundary::send(
                                                        {
                                                         dir => 'web/static/temp',
                                                         file => 'test.csv',
                                                         geo_file => 'geo.txt',
                                                         council_name => 'Peterborough City Council',
                                                         role_name => 'Test Users',
                                                         send_to => 'test@localhost.com',
                                                         send_from => 'me@example.com',
                                                         subject_body => "Your Report\n\nReport attached to email"
                                                        });
};

subtest 'open311 request handling', sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => ['peterborough' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $contact = $mech->create_contact_ok(body_id => $peterborough->id, category => 'Trees', email => 'TREES',
            extra => { _fields => [
                { description => 'emergency', code => 'emergency', required => 'true', variable => 'true' },
                { description => 'private land', code => 'private_land', required => 'true', variable => 'true' },
                { description => 'Light', code => 'PCC-light', required => 'true', automated => 'hidden_field' },
                { description => 'CSC Ref', code => 'PCC-skanska-csc-ref', required => 'false', variable => 'true', },
                { description => 'Tree code', code => 'colour', required => 'True', automated => 'hidden_field' },
            ] },
        );
        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', { category => 'Trees', latitude => 52.5609, longitude => 0.2405, cobrand => 'peterborough' });
        $p->push_extra_fields({ name => 'emergency', value => 'no'});
        $p->push_extra_fields({ name => 'private_land', value => 'no'});
        $p->push_extra_fields({ name => 'PCC-light', value => 'whatever'});
        $p->push_extra_fields({ name => 'PCC-skanska-csc-ref', value => '1234'});
        $p->push_extra_fields({ name => 'tree_code', value => 'tree-42'});
        $p->update;

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';
        is $p->send_method_used, 'Open311', 'Report sent via Open311';
        is $p->external_id, 248, 'Report has correct external ID';
        is $p->get_extra_field_value('emergency'), 'no';

        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[description]'), "Title Test 1 for " . $peterborough->id . " Detail\n\nSkanska CSC ref: 1234", 'Ref added to description';
        is $c->param('attribute[emergency]'), undef, 'no emergency param sent';
        is $c->param('attribute[private_land]'), undef, 'no private_land param sent';
        is $c->param('attribute[PCC-light]'), undef, 'no pcc- param sent';
        is $c->param('attribute[tree_code]'), 'tree-42', 'tree_code param sent';
        is $c->param('attribute[site_code]'), 'ROAD', 'site_code found';
    };
};

subtest "extra update params are sent to open311" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
    }, sub {
        Open311->_inject_response('servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>ezytreev-248</update_id></request_update></service_request_updates>');

        my $o = Open311->new(
            fixmystreet_body => $peterborough,
        );

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            external_id => 1, category => 'General fly tipping', send_state => 'sent',
            send_method_used => "Open311", cobrand => 'peterborough',
            extra => { _fields => [
                { name => 'Incident_Size', value => 'huge' },
            ] },
        });

        my $c = FixMyStreet::DB->resultset('Comment')->create({
            problem => $p, user => $p->user, anonymous => 't', text => 'Update text',
            problem_state => 'fixed - council', state => 'confirmed', mark_fixed => 0,
            confirmed => DateTime->now(),
        });

        my $id = $o->post_service_request_update($c);
        is $id, "ezytreev-248", 'correct update ID returned';
        my $cgi = CGI::Simple->new($o->test_req_used->content);
        is $cgi->param('description'), '[Customer FMS update] Update text', 'FMS update prefix included';
        is $cgi->param('service_request_id_ext'), $p->id, 'Service request ID included';
        is $cgi->param('service_code'), $flytipping->email, 'Service code included';
        is $cgi->param('attribute[Incident_Size]'), 'huge';

        $mech->get_ok('/report/' . $p->id);
        $mech->content_lacks('Please note that updates are not sent to the council.');
    };
};

my $problem;
subtest "bartec report with no geocode handled correctly" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
    }, sub {
        my $contact = $mech->create_contact_ok(body_id => $peterborough->id, category => 'Bins', email => 'Bartec-Bins');
        ($problem) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', { category => 'Bins', latitude => 52.5607, longitude => 0.2405, cobrand => 'peterborough', areas => ',2566,' });

        FixMyStreet::Script::Reports::send();

        $problem->discard_changes;
        is $problem->send_state, 'sent', 'Report marked as sent';

        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[postcode]'), undef, 'postcode param not set';
        is $cgi->param('attribute[house_no]'), undef, 'house_no param not set';
        is $cgi->param('attribute[street]'), undef, 'street param not set';
    };
};

subtest "update sent to Bartec" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
    }, sub {
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('Please note that updates are not sent to the council.');
        Open311->_inject_response('/servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>43</update_id></request_update></service_request_updates>');
        my $o = Open311::PostServiceRequestUpdates->new;
        my $c = FixMyStreet::DB->resultset('Comment')->create({
            problem => $problem, user => $problem->user, anonymous => 't', text => 'Update text',
            problem_state => 'fixed - council', state => 'confirmed', mark_fixed => 0,
            confirmed => DateTime->now(),
        });
        $c->discard_changes; # to get defaults
        $o->process_update($peterborough, $c);
        $c->discard_changes;
        is $c->send_state, 'sent';
    };
};

my $report;
subtest "extra bartec params are sent to open311" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
    }, sub {
        ($report) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'Bins',
            latitude => 52.5608,
            longitude => 0.2405,
            cobrand => 'peterborough',
            geocode => {
                display_name => '12 A Street, XX1 1SZ',
                address => {
                    house_number => '12',
                    road => 'A Street',
                    postcode => 'XX1 1SZ'
                }
            },
            extra => {
                contributed_by => $staffuser->id,
                external_status_code => 'EXT',
                _fields => [
                    { name => 'site_code', value => '12345', },
                    { name => 'PCC-light', value => 'light-ref', },
                ],
            },
        } );

        FixMyStreet::Script::Reports::send();

        $report->discard_changes;
        is $report->send_state, 'sent', 'Report marked as sent';

        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[postcode]'), 'XX1 1SZ', 'postcode param sent';
        is $cgi->param('attribute[house_no]'), '12', 'house_no param sent';
        is $cgi->param('attribute[street]'), 'A Street', 'street param sent';
        is $cgi->param('attribute[contributed_by]'), $staffuser->email, 'staff email address sent';
    };
};

for my $test (
    {
        lat => 52.5708,
        desc => 'council land - send by open311',
        method => 'Open311',
    },
    {
        lat => 52.5608,
        desc => 'leased council land - send by email',
        method => 'Blackhole',
    },
    {
        lat => 52.5508,
        desc => 'non council land - send by email',
        method => 'Blackhole',
    },
    {
        lat => 52.5408,
        desc => 'adopted road - send by open311',
        method => 'Open311',
    },
) {
    subtest "check get_body_sender: " . $test->{desc} => sub {
        FixMyStreet::override_config {
            STAGING_FLAGS => { send_reports => 1 },
            MAPIT_URL => 'http://mapit.uk/',
            ALLOWED_COBRANDS => 'peterborough',
            COBRAND_FEATURES => { open311_email => { peterborough => { flytipping => 'flytipping@example.org' } } },
        }, sub {
            my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
                category => 'General fly tipping',
                latitude => $test->{lat},
                longitude => 0.2505,
                cobrand => 'peterborough',
            });

            my $cobrand = FixMyStreet::Cobrand::Peterborough->new;
            my $sender = $cobrand->get_body_sender($peterborough, $p);
            is $sender->{method}, $test->{method}, "correct body sender set";

            $p->update({ send_state => 'sent' });
        };
    };
}

subtest 'GIS failure causes report sending to be deferred' => sub {
    $mock->unmock('_fetch_features');
    my $mock_gis = LWP::Protocol::PSGI->register(sub {
        return [503, ['Content-Type' => 'text/plain'], ['Service Unavailable']];
    }, host => 'tilma.mysociety.org');

    my ($report) = $mech->create_problems_for_body(1, $peterborough->id, 'Graffiti problem', {
        category => 'Non offensive graffiti', cobrand => 'peterborough',
        latitude => 52.5408, longitude => 0.2505,
    });

    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
    }, sub {
        FixMyStreet::Script::Reports::send();
    };

    $report->discard_changes;
    ok !$report->whensent, 'Report was not marked as sent';
    is $report->send_fail_reason, "No-op", 'Report has been deferred';
    $mock->mock('_fetch_features', \&mock_fetch_features);
};

subtest "flytipping on PCC land is sent by open311 and email" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => {
            flytipping => 'flytipping@example.org',
            flytipping_witnessed => 'witnessed@example.org',
        } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'General fly tipping',
            latitude => 52.57146,
            longitude => -0.24201,
            areas => ',2566,',
            cobrand => 'peterborough',
            geocode => {
                display_name => '12 A Street, XX1 1SZ',
                address => {
                    house_number => '12',
                    road => 'A Street',
                    postcode => 'XX1 1SZ'
                }
            },
            extra => {
                _fields => [
                    { name => 'site_code', value => '12345', },
                    { name => 'Land_Type', value => 'Highway - L01', },
                    { name => 'Primary_Waste_Type', value => 'Tyres - W06', },
                    { name => 'Incident_Size', value => 'Small Van Load - S03', },
                ],
            },
        } );

        FixMyStreet::Script::Reports::send();
        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';
        is $p->get_extra_metadata('sent_to')->[0], 'flytipping@example.org', 'sent_to extra metadata is set';
        is $p->state, 'confirmed', 'report state unchanged';
        is $p->comments->count, 0, 'no comment added';
        my $cgi = CGI::Simple->new(Open311->test_req_used->content);
        is $cgi->param('service_code'), 'FLY', 'service code is correct';
        is $cgi->param('attribute[Land_Type]'), 'Highway - L01';

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
        is $email->header('To'), '"Environmental Services" <flytipping@example.org>', 'email sent to correct address';
        like $email->header('Subject'), qr/\[Censorship checking only\] Problem Report: /;

        subtest 'inspector form makes update when metadata changed' => sub {
            $mech->log_in_ok( $staffuser->email );
            $mech->get_ok('/report/' . $p->id);
            $mech->submit_form_ok({ button => 'save', with_fields => { category_generalflytipping_Incident_Size => 'tiny', include_update => 0 } });
            $p->discard_changes;
            is $p->get_extra_field_value('Incident_Size'), 'tiny';
        };
    };
};

subtest "flytipping on PCC land by staff does not send censorship checking email" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => {
            flytipping => 'flytipping@example.org',
            flytipping_witnessed => 'witnessed@example.org',
        } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'General fly tipping',
            latitude => 52.57146,
            longitude => -0.24201,
            areas => ',2566,',
            cobrand => 'peterborough',
            geocode => {
                display_name => '12 A Street, XX1 1SZ',
                address => {
                    house_number => '12',
                    road => 'A Street',
                    postcode => 'XX1 1SZ'
                }
            },
            extra => {
                contributed_by => $staffuser->id,
                _fields => [
                    { name => 'site_code', value => '12345', },
                    { name => 'Land_Type', value => 'Highway - L01', },
                    { name => 'Primary_Waste_Type', value => 'Tyres - W06', },
                    { name => 'Incident_Size', value => 'Small Van Load - S03', },
                ],
            },
        } );

        FixMyStreet::Script::Reports::send();
        $mech->email_count_is(0);
    };
};

subtest "flytipping on PCC land witnessed is sent by open311 and two emails" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => {
            flytipping => 'flytipping@example.org',
            flytipping_witnessed => 'witnessed@example.org',
        } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'General fly tipping',
            latitude => 52.5708,
            longitude => 0.2505,
            cobrand => 'peterborough',
            extra => {
                _fields => [
                    { name => 'site_code', value => '12345', },
                    { name => 'pcc-witness', value => 'yes', },
                ],
            },
        } );

        FixMyStreet::Script::Reports::send();
        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';
        is $p->get_extra_metadata('sent_to')->[1], 'flytipping@example.org', 'sent_to extra metadata is set';
        is $p->get_extra_metadata('sent_to')->[0], 'witnessed@example.org', 'sent_to extra metadata is set';
        is $p->state, 'confirmed', 'report state unchanged';
        is $p->comments->count, 0, 'no comment added';
        my $cgi = CGI::Simple->new(Open311->test_req_used->content);
        is $cgi->param('service_code'), 'FLY', 'service code is correct';

        $mech->email_count_is(2);
        my @email = $mech->get_email;
        is $email[0]->header('To'), '"Environmental Services" <flytipping@example.org>', 'email sent to correct address';
        like $email[0]->header('Subject'), qr/\[Censorship checking only\] Problem Report: /;
        is $email[1]->header('To'), '"Environmental Enforcement" <witnessed@example.org>', 'email sent to correct address';
        like $email[1]->header('Subject'), qr/\[URGENT - Evidence available\] Problem Report: /;
    };
};

subtest "flytipping/graffiti on non PCC land is not sent anywhere" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => {
            flytipping => 'flytipping@example.org',
            flytipping_witnessed => 'witnessed@example.org',
        } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'General fly tipping',
            latitude => 52.5608,
            longitude => 0.2405,
            cobrand => 'peterborough',
            geocode => {
                display_name => '12 A Street, XX1 1SZ',
                address => {
                    house_number => '12',
                    road => 'A Street',
                    postcode => 'XX1 1SZ'
                }
            },
            extra => {
                _fields => [
                    { name => 'site_code', value => '12345', },
                ],
            },
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';
        is $p->get_extra_metadata('flytipping_email'), undef, 'flytipping_email extra metadata unset';
        is $p->get_extra_metadata('sent_to'), undef, 'sent_to extra metadata not set';
        is $p->state, 'closed', 'report closed having sent email';
        is $p->comments->count, 1, 'comment added';
        like $p->comments->first->text, qr/The area selected is not owned or maintained by Peterborough City Council/, 'correct comment text';
        ok !Open311->test_req_used, 'no open311 sent';

        $mech->email_count_is(0);

        ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'Non offensive graffiti',
            latitude => 52.5608,
            longitude => 0.2405,
            cobrand => 'peterborough',
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';
        is $p->get_extra_metadata('flytipping_email'), undef, 'flytipping_email extra metadata unset';
        is $p->get_extra_metadata('sent_to'), undef, 'sent_to extra metadata not set';
        is $p->state, 'closed', 'report closed having sent email';
        is $p->comments->count, 1, 'comment added';
        like $p->comments->first->text, qr/For graffiti on private land/, 'correct comment text';
        ok !Open311->test_req_used, 'no open311 sent';

        $mech->email_count_is(0);
    };
};

subtest "flytipping in a CCTV camera zone sends the enforcement email" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => {
            flytipping => 'flytipping@example.org',
            flytipping_cctv => 'cctv@example.org',
        } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'General fly tipping',
            latitude => 52.5708,
            longitude => 0.2515,
            cobrand => 'peterborough',
            geocode => {
                display_name => '12 A Street, XX1 1SZ',
                address => {
                    house_number => '12',
                    road => 'A Street',
                    postcode => 'XX1 1SZ'
                }
            },
        } );

        FixMyStreet::Script::Reports::send();
        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';
        my $cgi = CGI::Simple->new(Open311->test_req_used->content);
        is $cgi->param('service_code'), 'FLY', 'service code is correct';

        my @email = $mech->get_email;
        $mech->email_count_is(2);

        is $email[0]->header('To'), '"Environmental Services" <flytipping@example.org>', 'standard flytipping email sent';
        like $email[0]->header('Subject'), qr/\[Censorship checking only\] Problem Report: /, 'standard flytipping email keeps the censorship subject';
        is $email[1]->header('To'), '"Environmental Enforcement" <cctv@example.org>', 'CCTV enforcement email sent';
        like $email[1]->header('Subject'), qr/\[Priority Evidence Available \(Fixed CCTV\)\] Problem Report: /, 'CCTV email uses the CCTV subject prefix';
        like $mech->get_text_body_from_email($email[1]), qr/within a CCTV camera zone/i, 'CCTV email explains why it was sent';
    };
};

subtest "flytipping not in a CCTV camera zone does not send the enforcement email" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => {
            flytipping => 'flytipping@example.org',
            flytipping_cctv => 'cctv@example.org',
        } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'General fly tipping',
            latitude => 52.57146,
            longitude => -0.24201,
            areas => ',2566,',
            cobrand => 'peterborough',
            geocode => {
                display_name => '12 A Street, XX1 1SZ',
                address => {
                    house_number => '12',
                    road => 'A Street',
                    postcode => 'XX1 1SZ'
                }
            },
        });

        FixMyStreet::Script::Reports::send();
        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';
        $mech->email_count_is(1);
        my $email = $mech->get_email;
        is $email->header('To'), '"Environmental Services" <flytipping@example.org>', 'only standard flytipping email sent, not CCTV enforcement';
    };
};

subtest "flytipping witnessed in a CCTV camera zone sends three emails" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => {
            flytipping => 'flytipping@example.org',
            flytipping_witnessed => 'witnessed@example.org',
            flytipping_cctv => 'cctv@example.org',
        } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'General fly tipping',
            latitude => 52.5708,
            longitude => 0.2515,
            cobrand => 'peterborough',
            geocode => {
                display_name => '12 A Street, XX1 1SZ',
                address => {
                    house_number => '12',
                    road => 'A Street',
                    postcode => 'XX1 1SZ'
                }
            },
            extra => {
                _fields => [
                    { name => 'pcc-witness', value => 'yes', },
                ],
            },
        });

        FixMyStreet::Script::Reports::send();
        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';

        my @email = $mech->get_email;
        $mech->email_count_is(3);
        is $email[0]->header('To'), '"Environmental Services" <flytipping@example.org>', 'standard flytipping email sent';
        is $email[1]->header('To'), '"Environmental Enforcement" <witnessed@example.org>', 'witnessed enforcement email sent';
        is $email[2]->header('To'), '"Environmental Enforcement" <cctv@example.org>', 'CCTV enforcement email sent';
        like $email[2]->header('Subject'), qr/\[Priority Evidence Available \(Fixed CCTV\)\] Problem Report: /, 'CCTV email uses the CCTV subject prefix';
    };
};

subtest "sharps report also emailed" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => {
            sharps => 'sharps@example.org,sharps2@example.org',
        } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'Sharps',
        });

        FixMyStreet::Script::Reports::send();
        $p->discard_changes;
        is $p->send_state, 'sent', 'Report marked as sent';

        my $email = $mech->get_email;
        is $email->header('To'), 'sharps@example.org, sharps2@example.org';
    };
};

subtest 'Dashboard CSV extra columns' => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    $report->update({
        state => 'unable to fix',
    });
    $mech->log_in_ok( $staffuser->email );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('"Reported As","Staff User",USRN,"Nearest address","External ID","External status code",Light,"CSC Ref"');
    $mech->content_like(qr/"No further action",.*?,peterborough,,[^,]*counciluser\@example.com,12345,"12 A Street, XX1 1SZ",248,EXT,light-ref,/);
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_lacks('DBState');
        $mech->content_contains('"Reported As","Staff User",USRN,"Nearest address","External ID","External status code",Light,"CSC Ref"');
        $mech->content_like(qr/"No further action",.*?,peterborough,,[^,]*counciluser\@example.com,12345,"12 A Street, XX1 1SZ",248,EXT,light-ref,/);
        $mech->get_ok('/dashboard?export=1&state=unable+to+fix');
        $mech->content_contains("No further action");
        $mech->get_ok('/dashboard?export=1&state=confirmed');
        $mech->content_lacks("No further action");
    };
};

subtest 'Resending between backends' => sub {
    $staffuser->user_body_permissions->create({ body => $peterborough, permission_type => 'report_edit' });
    $mech->create_contact_ok(body_id => $peterborough->id, category => 'Pothole', email => 'Bartec-POT');
    $mech->create_contact_ok(body_id => $peterborough->id, category => 'Fallen tree', email => 'Ezytreev-Fallen');
    $mech->create_contact_ok(body_id => $peterborough->id, category => 'Flying tree', email => 'Ezytreev-Flying');
    $mech->create_contact_ok(body_id => $peterborough->id, category => 'Graffiti', email => 'graffiti@example.org', send_method => 'Email');

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
    }, sub {
        # $problem is in Bins category from creation, which is Bartec
        my $whensent = $problem->whensent;
        $mech->get_ok('/admin/report_edit/' . $problem->id);
        foreach (
            { category => 'Pothole', resent => 0 },
            { category => 'Fallen tree', resent => 1 },
            { category => 'Flying tree', resent => 0 },
            { category => 'Graffiti', resent => 1, method => 'Email' },
            { category => 'Trees', resent => 1 }, # Not due to forced, but due to send method change
            { category => 'Bins', resent => 1 },
        ) {
            $mech->submit_form_ok({ with_fields => { category => $_->{category} } }, "Switch to $_->{category}");
            $problem->discard_changes;
            if ($_->{resent}) {
                is $problem->send_state, 'unprocessed', "Marked for resending";
                $problem->update({ whensent => $whensent, send_method_used => $_->{method} || 'Open311', send_state => 'sent' }); # reset as sent
            } else {
                is $problem->send_state, 'sent', "Not marked for resending";
            }
        }
    };
};

$mech->log_out_ok;

foreach my $cobrand ( "peterborough", "fixmystreet" ) {
    subtest "waste categories aren't available outside /waste on $cobrand cobrand" => sub {
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
            ALLOWED_COBRANDS => $cobrand,
        }, sub {
            $peterborough->contacts->delete_all;
            my $contact = $mech->create_contact_ok(body_id => $peterborough->id, category => 'Litter Bin Needs Emptying', email => 'Bartec-Bins');
            my $waste = $mech->create_contact_ok(body_id => $peterborough->id, category => 'Missed Collection', email => 'Bartec-MissedCollection');
            $waste->set_extra_metadata(type => 'waste');
            $waste->update;

            subtest "not when getting new report categories via AJAX" => sub {
                my $json = $mech->get_ok_json('/report/new/ajax?latitude=52.57146&longitude=-0.24201');
                is_deeply $json->{by_category}, { "Litter Bin Needs Emptying" => { bodies => [ 'Peterborough City Council' ] } }, "Waste category not in JSON";
                lacks_string($json, "Missed Collection", "Waste category not mentioned at all");
            };

            subtest "not when making a new report directly" => sub {
                $mech->get_ok('/report/new?latitude=52.57146&longitude=-0.24201');
                $mech->content_contains("Litter Bin Needs Emptying", "non-waste category mentioned");
                $mech->content_lacks("Missed Collection", "waste category not mentioned");
            };

            subtest "not when browsing /around" => sub {
                $mech->get_ok('/around?latitude=52.57146&longitude=-0.24201');
                $mech->content_contains("Litter Bin Needs Emptying", "non-waste category mentioned");
                $mech->content_lacks("Missed Collection", "waste category not mentioned");
            };

            subtest "not when browsing all reports" => sub {
                $mech->get_ok('/reports/Peterborough');
                $mech->content_contains("Litter Bin Needs Emptying", "non-waste category mentioned");
                $mech->content_lacks("Missed Collection", "waste category not mentioned");
            };

        };
    };
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'peterborough',
}, sub {
  SKIP: {
        skip( "No postgis set in environment", 4 ) unless $ENV{WITH_POSTGIS};
        subtest "sending report on user role within boundary" => sub {
            my $no_data = '"Report ID",Title,Detail,"User Name",Category,Subcategory,Created,Confirmed,Acknowledged,Fixed,Closed,Status,Latitude,Longitude,Query,Ward,Easting,Northing,"Report URL","Device Type","Site Used","Reported As","Staff User",USRN,"Nearest address","External ID","External status code"' . "\n" . '$';
            for my $test(
                         {
                          reporter => { user => $trusteduser, latitude => '52.574671', longitude => '-0.24259' },
                          csv => 'REPORTID,"Title',
                          message => 'Trusted user report made in zone is in data',
                         },
                         {
                          reporter => { user => $trusteduser, latitude => '52.580865', longitude => '-0.248609' },
                          csv => $no_data,
                          message => 'Trusted user report made outside zone is not in data',
                         },
                         {
                          reporter => { user => $staffuser, latitude => '52.574671', longitude => '-0.24259' },
                          csv => $no_data,
                          message => 'Another user report made in zone is not in data',
                         },
                         {
                          reporter => { user => $multiple_roles_user, latitude => '52.574671', longitude => '-0.24259' },
                          csv => 'REPORTID,"Title',
                          message => 'User with multiple roles report made in zone is in data',
                         },
                        )
              {

                  my ($problem) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', { user => $test->{reporter}->{user}, category => 'Trees', latitude => $test->{reporter}->{latitude}, longitude => $test->{reporter}->{longitude}, cobrand => 'peterborough' });
                  _trigger_sending_report;
                  my $email = $mech->get_email;
                  is $email->header('Subject'), 'Your Report', 'Subject set correctly';
                  is $email->header('From'), 'me@example.com', 'Sets the from';
                  is $email->header('To'), 'test@localhost.com', 'Sets the to';
                  my @parts = $email->subparts;
                  my $id = $problem ? $problem->id : undef;
                  $test->{csv} =~ s/REPORTID/$id/ if $id;
                  like decode_base64($parts[1]->body_raw), qr/$test->{csv}/, $test->{message};
                  $problem->delete;
              }
            $mech->clear_emails_ok;
            path("web/static/temp/geo.txt")->remove;
        };
    };
};

sub _geodata {
    'POLYGON((-0.233545002405502 52.5653538382882,-0.236873036597264 52.5657508178068,-0.23876883270984 52.5660743376894,-0.24066605098008 52.5665434031864,-0.24176904659214 52.5667276140371,-0.242296763582797 52.5664091564646,-0.242748319446151 52.56626034523,-0.243423035331609 52.5661025016128,-0.243847336867412 52.5660273356078,-0.243959930306833 52.5661032338445,-0.244533785957033 52.5670880476814,-0.244888471676409 52.56761761715,-0.245561213762427 52.5686038913731,-0.246529126136361 52.5698777813042,-0.24718817263169 52.5707131792176,-0.247940815283912 52.571682541838,-0.249080328698166 52.5731216660794,-0.249948303727025 52.5729356222286,-0.249738167558888 52.5726214783266,-0.250042639812737 52.572606230235,-0.250775930404238 52.5726071920562,-0.250976204962253 52.5725632496015,-0.251188920199824 52.5725120856503,-0.251594300725226 52.5724045227321,-0.251917421827361 52.572327833428,-0.252207566184135 52.5723219147884,-0.252317859596652 52.5723630794502,-0.252432361348952 52.5724058156945,-0.252539014922174 52.5727087173095,-0.253127412457065 52.573832312335,-0.253511984628052 52.5746093842175,-0.251818170366069 52.5749158483877,-0.252121657112045 52.5754928505928,-0.250932483300328 52.5757946974362,-0.251400200024676 52.57647055292,-0.250296321692215 52.5766169632607,-0.250183679238103 52.5764646345236,-0.249647706886736 52.5764697296914,-0.249491518983581 52.5764172802502,-0.249218060480705 52.5764479501194,-0.249004803718626 52.5765566489015,-0.24837409077398 52.5766553162628,-0.246759707856042 52.576812702258,-0.246257996669507 52.5768515557581,-0.245795171877465 52.5768678424513,-0.244518422332789 52.5768142073542,-0.244100505110865 52.5768157239085,-0.243905908724532 52.5769324054059,-0.243768942768643 52.5771342824182,-0.243312654275237 52.5769486000433,-0.242660442513913 52.5766375942578,-0.242158574032959 52.5764323985,-0.24114130588084 52.5778286215615,-0.240177653531705 52.5791256817751,-0.239727291186831 52.5797785347188,-0.239541318652643 52.5796793450754,-0.239308898559107 52.5793171878874,-0.239054107303968 52.5788814152642,-0.238537718424572 52.5786538859654,-0.237888618939662 52.5782623847621,-0.237719938216041 52.5782058767336,-0.237423005376914 52.5781898857444,-0.237095208750473 52.5781541498805,-0.236719112447596 52.5780598390972,-0.236427906473173 52.5779012216403,-0.236172826438135 52.5776312891763,-0.235835818567483 52.5771942844987,-0.235621341088364 52.5768593867265,-0.235596359864661 52.5766931634575,-0.235496069397971 52.5765103904049,-0.235371999017678 52.5764468295289,-0.235168616025416 52.5763088031857,-0.235126202518237 52.5761037498035,-0.235218963197513 52.576000993249,-0.235538303662568 52.5756161955986,-0.235757778429729 52.5753533329099,-0.235999033811559 52.5748632304642,-0.236185660953522 52.5743144598607,-0.236370891165428 52.5738003802964,-0.236534646835746 52.5735058302647,-0.236796706289281 52.573127890313,-0.23692404245556 52.572794227222,-0.236992269687124 52.5725136815587,-0.237114419626373 52.5713622567943,-0.237060881648215 52.5712766059742,-0.236857813162263 52.5712890096932,-0.236040740926454 52.5714581190511,-0.234429251435352 52.5718622269243,-0.23430408944673 52.5719837843317,-0.234188328286753 52.5721864792921,-0.23408090634589 52.5723391570072,-0.233646816845637 52.5724291068792,-0.233137423941137 52.5725025039239,-0.232648095191613 52.5725491985185,-0.232230374124918 52.5725468196253,-0.231977770138586 52.5725314774494,-0.231429980650422 52.5724577272295,-0.230252005782331 52.5723128438023,-0.229058319968526 52.5720867178658,-0.228533095015589 52.5719245798986,-0.229176670497831 52.57150607947,-0.229953905301628 52.57091215122,-0.230426484560575 52.5704949447109,-0.231099083773311 52.5698261618095,-0.231528752355094 52.5693735967524,-0.231995623925859 52.5687827332904,-0.23237946754069 52.568209913112,-0.232701281590353 52.567605310696,-0.232989596739146 52.5670464909925,-0.233139638036476 52.5666206015622,-0.233329026486588 52.5661605868627,-0.233545002405502 52.5653538382882))
'
}

done_testing;
