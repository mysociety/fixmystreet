use FixMyStreet::TestMech;
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Reports;
use File::Temp 'tempdir';
use Test::MockModule;
use CGI::Simple;
use Test::LongString;
use Open311::PostServiceRequestUpdates;
use t::Mock::Nominatim;

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
$mock->mock('_fetch_features', sub {
    my ($self, $args, $x, $y) = @_;
    if ( $args->{type} && $args->{type} eq 'arcgis' ) {
        # council land
        if ( $x == 552617 && $args->{url} =~ m{4/query} ) {
            return [ { geometry => { type => 'Point' } } ];
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
});

my $mech = FixMyStreet::TestMech->new;

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};
my $peterborough = $mech->create_body_ok(2566, 'Peterborough City Council', $params, { cobrand => 'peterborough' });
my $contact = $mech->create_contact_ok(email => 'FLY', body_id => $peterborough->id, category => 'General fly tipping');
my $user = $mech->create_user_ok('peterborough@example.org', name => 'Council User', from_body => $peterborough);
$peterborough->update( { comment_user_id => $user->id } );

my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $peterborough);

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
        is $c->param('attribute[description]'), "Title Test 1 for " . $peterborough->id . " Detail\r\n\r\nSkanska CSC ref: 1234", 'Ref added to description';
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
        my $contact = $mech->create_contact_ok(body_id => $peterborough->id, category => 'Trees', email => 'TREES');
        Open311->_inject_response('servicerequestupdates.xml', '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>ezytreev-248</update_id></request_update></service_request_updates>');

        my $o = Open311->new(
            fixmystreet_body => $peterborough,
        );

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            external_id => 1, category => 'Trees', send_state => 'sent',
            send_method_used => "Open311", cobrand => 'peterborough' });

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
        is $cgi->param('service_code'), $contact->email, 'Service code included';

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

subtest "no update sent to Bartec" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
    }, sub {
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('Please note that updates are not sent to the council.');
        my $o = Open311::PostServiceRequestUpdates->new;
        my $c = FixMyStreet::DB->resultset('Comment')->create({
            problem => $problem, user => $problem->user, anonymous => 't', text => 'Update text',
            problem_state => 'fixed - council', state => 'confirmed', mark_fixed => 0,
            confirmed => DateTime->now(),
        });
        $c->discard_changes; # to get defaults
        $o->process_update($peterborough, $c);
        $c->discard_changes;
        is $c->send_state, 'skipped';
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
        method => 'Email',
    },
    {
        lat => 52.5508,
        desc => 'non council land - send by email',
        method => 'Email',
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

subtest "flytipping on PCC land is sent by open311 and email" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => { flytipping => 'flytipping@example.org' } } },
    }, sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $peterborough->id, 'Title', {
            category => 'General fly tipping',
            latitude => 52.5708,
            longitude => 0.2505,
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
        is $p->get_extra_metadata('sent_to')->[0], 'flytipping@example.org', 'sent_to extra metadata is set';
        is $p->state, 'confirmed', 'report state unchanged';
        is $p->comments->count, 0, 'no comment added';
        my $cgi = CGI::Simple->new(Open311->test_req_used->content);
        is $cgi->param('service_code'), 'FLY', 'service code is correct';

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
        is $email->header('To'), '"Environmental Services" <flytipping@example.org>', 'email sent to correct address';
    };
};

subtest "flytipping on PCC land witnessed is only sent by email" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => { flytipping => 'flytipping@example.org' } } },
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

        my $test_data = FixMyStreet::Script::Reports::send();
        $p->discard_changes;
        ok !$test_data->{test_req_used}, 'open311 not sent';

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
        is $email->header('To'), '"Environmental Services" <flytipping@example.org>', 'email sent to correct address';
    };
};

subtest "flytipping on non PCC land is emailed" => sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'peterborough',
        COBRAND_FEATURES => { open311_email => { peterborough => { flytipping => 'flytipping@example.org' } } },
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
        is $p->get_extra_metadata('sent_to')->[0], 'flytipping@example.org', 'sent_to extra metadata set';
        is $p->state, 'closed', 'report closed having sent email';
        is $p->comments->count, 1, 'comment added';
        like $p->comments->first->text, qr/You can report cases/, 'correct comment text';
        ok !Open311->test_req_used, 'no open311 sent';

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
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
}

done_testing;
