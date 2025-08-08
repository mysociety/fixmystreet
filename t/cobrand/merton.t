use Test::MockModule;
use FixMyStreet::TestMech;
use HTML::Selector::Element qw(find);
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;
my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Merton');

$cobrand->mock('area_types', sub { [ 'LBO' ] });

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $merton = $mech->create_body_ok(2500, 'Merton Council', {
    api_key => 'aaa',
    jurisdiction => 'merton',
    endpoint => 'http://endpoint.example.org',
    send_method => 'Open311',
    comment_user => $superuser,
    cobrand => 'merton'
});
my @cats = ('Litter', 'Other', 'Potholes', 'Traffic lights');
for my $contact ( @cats ) {
    $mech->create_contact_ok(body_id => $merton->id, category => $contact, email => "\L$contact\@merton.example.org",
        extra => { anonymous_allowed => 1 });
}

my $hackney = $mech->create_body_ok(2508, 'Hackney Council', { cobrand => 'hackney' });
for my $contact ( @cats ) {
    $mech->create_contact_ok(body_id => $hackney->id, category => $contact, email => "\L$contact\@hackney.example.org");
}

my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $merton);
my $normaluser = $mech->create_user_ok('normaluser@example.com', name => 'Normal User');
my $hackneyuser = $mech->create_user_ok('hackneyuser@example.com', name => 'Hackney User', from_body => $hackney);

$normaluser->update({ phone => "+447123456789" });

my ($problem1) = $mech->create_problems_for_body(1, $merton->id, 'Title', {
    postcode => 'SM4 5DX', areas => ",2500,", category => 'Potholes',
    cobrand => 'merton', user => $normaluser, state => 'fixed'
});

my ($problem2) = $mech->create_problems_for_body(1, $hackney->id, 'Title', {
    postcode => 'E8 1DY', areas => ",2508,", category => 'Litter',
    cobrand => 'fixmystreet', user => $normaluser, state => 'fixed'
});


FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'merton', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        anonymous_account => {
            merton => 'anonymous'
        },
    },
}, sub {
    ok $mech->host('merton.fixmystreet.com'), 'set host';

    subtest 'cobrand homepage displays council name' => sub {
        $mech->get_ok('/');
        $mech->content_contains('Merton Council');
    };

    subtest 'reports page displays council name' => sub {
        $mech->get_ok('/reports/Merton');
        $mech->content_contains('Merton Council');
    };

    subtest 'External ID is shown on report page' => sub {
        my ($report) = $mech->create_problems_for_body(1, $merton->id, 'Test Report', {
            category => 'Litter', cobrand => 'merton',
            external_id => 'merton-123', whensent => \'current_timestamp',
        });
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains("Council ref:&nbsp;" . $report->external_id);
    };

    subtest "test report creation anonymously by button" => sub {
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'SM4 5DX', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok( { with_fields => { category => 'Litter', } }, "submit category" );
        $mech->submit_form_ok(
            {
                button => 'report_anonymously',
                with_fields => {
                    title => 'Anonymous Test Report 1',
                    detail => 'Test report details.',
                    category => 'Litter',
                }
            },
            "submit report anonymously"
        );
        my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Anonymous Test Report 1'});
        ok $report, "Found the report";

        $mech->content_contains('Your issue has been sent.');

        is_deeply $mech->page_errors, [], "check there were no errors";

        is $report->state, 'confirmed', "report confirmed";
        $mech->get_ok( '/report/' . $report->id );

        is $report->bodies_str, $merton->id;
        is $report->name, 'Anonymous user';
        is $report->user->email, 'anonymous@anonymous-fms.merton.gov.uk';
        is $report->anonymous, 1; # Doesn't change behaviour here, but uses anon account's name always
        is $report->get_extra_metadata('contributed_as'), 'anonymous_user';

        my $alert = FixMyStreet::App->model('DB::Alert')->find( {
            user => $report->user,
            alert_type => 'new_updates',
            parameter => $report->id,
        } );
        is $alert, undef, "no alert created";

        $mech->not_logged_in_ok;
    };

    subtest "hides the TfL River Piers category" => sub {
        my $tfl = $mech->create_body_ok(2500, 'TfL');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers - Cleaning', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers Damage doors and glass', email => 'tfl@example.org');

        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.400975&longitude=-0.19655');
        my $categories = [sort keys %{$json->{by_category}}];
        is_deeply $categories, ['Litter', 'Other', 'Potholes', 'Traffic lights'], "Merton doesn't have any River Piers categories";
    };
};

subtest 'only Merton staff can reopen closed reports on Merton cobrand' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'merton' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        test_reopen_problem($normaluser, $problem1);
        test_reopen_problem($counciluser, $problem1);
    };
};

subtest 'only Merton staff can reopen closed reports in Merton on fixmystreet.com' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet', 'merton' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        test_reopen_problem($normaluser, $problem1);
        test_reopen_problem($counciluser, $problem1);
    };
};

subtest 'staff and problems for other bodies are not affected by this change on fixmystreet.com' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        test_visit_problem($normaluser, $problem2);
        test_visit_problem($hackneyuser, $problem2);
    };
};

my $kingston = $mech->create_body_ok(2480, 'Kingston upon Thames Council', {
    cobrand => 'kingston'
});

my @kingston_cats = ('Graffiti', 'Fly-tipping');
for my $contact ( @kingston_cats ) {
    $mech->create_contact_ok(body_id => $kingston->id, category => $contact, email => "\L$contact\@kingston.example.org",);
}

FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => 2480, body_id => $merton->id });

subtest 'Merton responsible for park in Kingston' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'merton', 'kingston', 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        foreach my $host (qw/merton www/) {
            subtest "reports on $host cobrand in Commons Extension only has Merton categories" => sub {
                $mech->host("$host.fixmystreet.com");

                $cobrand->mock('_fetch_features', sub { [ { "ms:parks" => { "ms:SITE_CODE" => 'COMMONS' } } ] });
                $mech->get_ok("/report/new/ajax?longitude=-0.254369&latitude=51.427796");
                $mech->content_contains('Litter');
                $mech->content_lacks('Graffiti');
            }
        };
        subtest "report on Kingston Cobrand from Merton is not permitted if not Commons Extension" => sub {
            $mech->host("merton.fixmystreet.com");
            $cobrand->mock('_fetch_features', sub { [] }); # Mock that this isn't the Commons Extension
            $mech->get_ok("/report/new/ajax?longitude=-0.254369&latitude=51.427796");
            $mech->content_contains('That location is not covered by Merton Council');
        };
        subtest "report on Kingston from FMS Cobrand if not on Commons Extension only has Kingston categories" => sub {
            $mech->host("www.fixmystreet.com");
            $cobrand->mock('_fetch_features', sub { [] }); # Mock that this isn't the Commons Extension
            $mech->get_ok("/report/new/ajax?longitude=-0.254369&latitude=51.427796");
            $mech->content_lacks('Litter');
            $mech->content_contains('Graffiti');
        }
    }
};

sub test_reopen_problem {
    my ($user, $problem) = @_;
    $mech->log_in_ok( $user->email );
    $mech->get_ok('/report/' . $problem->id);
    $mech->content_contains("banner--fixed");
    if ($user->from_body) {
        my $page = HTML::TreeBuilder->new_from_content($mech->content());
        ok (my $select = $page->find('select#state'), 'State selection dropdown exists.');
    } else {
        ok $mech->content_lacks("This problem has not been fixed");
    }
    $mech->log_out_ok;
}

sub test_visit_problem {
    my ($user, $problem) = @_;
    $mech->log_in_ok( $user->email );
    $mech->get_ok('/report/' . $problem->id);
    $mech->content_contains("banner--fixed");
    $mech->log_out_ok;
}

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'merton' ],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        anonymous_account => {
            merton => 'anonymous'
        },
    },
    STAGING_FLAGS => { send_reports => 1 },
}, sub {
    subtest 'check open311 inclusion of service value into extra data' => sub {
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'SM4 5DX', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report 2',
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    username_register => 'test-1@example.com',
                    category      => 'Litter',
                }
            },
            "submit good details"
        );
        my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 2'});
        ok $report, "Found the report";
        is $report->get_extra_field_value("service"), 'desktop', 'origin service recorded in extra data too';
    };

    subtest 'anonymous reports have service "unknown"' => sub {
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'SM4 5DX', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok( { with_fields => { category => 'Litter', } }, "submit category");
        $mech->submit_form_ok(
            {
                button => 'report_anonymously',
                with_fields => {
                    title => 'Test Report 3',
                    detail => 'Test report details.',
                    category => 'Litter',
                }
            },
            "submit report anonymously"
        );
        my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 3'});
        ok $report, "Found the report";
        is $report->get_extra_field_value("service"), 'unknown', 'origin service recorded in extra data too';
    };

    subtest 'ensure USRN is added to report when sending over open311' => sub {
        my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::Merton');
        $ukc->mock('_fetch_features', sub {
            my ($self, $cfg, $x, $y) = @_;
            return [
                {
                    properties => { usrn => 'USRN1234' },
                    geometry => {
                        type => 'LineString',
                        coordinates => [ [ $x-2, $y+2 ], [ $x+2, $y+2 ] ],
                    }
                },
            ];
        });

        my ($report) = $mech->create_problems_for_body(1, $merton->id, 'Test report', {
            category => 'Litter', cobrand => 'merton',
            latitude => 51.400975, longitude => -0.19655, areas => '2500',
        });

        FixMyStreet::Script::Reports::send();
        $report->discard_changes;

        ok $report->whensent, 'report was sent';
        is $report->get_extra_field_value('usrn'), 'USRN1234', 'correct USRN recorded in extra data';
    };
};

subtest "hides duplicate updates from endpoint" => sub {
    my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );
    my ($p) = $mech->create_problems_for_body(1, $merton->id, '', { lastupdate => $dt });
    $p->update({ external_id => "merton-" . $p->id });

    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>UPDATE_1</update_id>
    <service_request_id>SERVICE_ID</service_request_id>
    <status>IN_PROGRESS</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    <request_update>
    <update_id>UPDATE_2</update_id>
    <service_request_id>SERVICE_ID</service_request_id>
    <status>IN_PROGRESS</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    </service_requests_updates>
    };

    my $update_dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new);

    $requests_xml =~ s/SERVICE_ID/merton-@{[$p->id]}/g;
    $requests_xml =~ s/UPDATED_DATETIME/$update_dt/g;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $counciluser,
        current_open311 => $o,
        current_body => $merton,
    );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'merton',
    }, sub {
        $update->process_body;
    };

    $p->discard_changes;
    is $p->comments->search({ state => 'confirmed' })->count, 1;
};

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

subtest 'updating of waste reports' => sub {
    my $date = DateTime->now->subtract(days => 1)->strftime('%Y-%m-%dT%H:%M:%SZ');
    my $integ = Test::MockModule->new('SOAP::Lite');
    $integ->mock(call => sub {
        my ($cls, @args) = @_;
        my $method = $args[0]->name;
        if ($method eq 'GetEvent') {
            my ($key, $type, $value) = ${$args[3]->value}->value;
            my $external_id = ${$value->value}->value->value;
            my ($waste, $event_state_id, $resolution_code) = split /-/, $external_id;
            my $data = [];
            return SOAP::Result->new(result => {
                Guid => $external_id,
                EventStateId => $event_state_id,
                EventTypeId => '1636',
                LastUpdatedDate => { OffsetMinutes => 60, DateTime => $date },
                ResolutionCodeId => $resolution_code,
                Data => { ExtensibleDatum => $data },
            });
        } elsif ($method eq 'GetEventType') {
            return SOAP::Result->new(result => {
                Workflow => { States => { State => [
                    { CoreState => 'New', Name => 'New', Id => 12396 },
                    { CoreState => 'Pending', Name => 'Allocated to Crew', Id => 12398 },
                    { CoreState => 'Closed', Name => 'Partially Completed', Id => 12399 },
                    { CoreState => 'Closed', Name => 'Completed', Id => 12400 },
                    { CoreState => 'Closed', Name => 'Not Completed', Id => 12401 },
                    { CoreState => 'Cancelled', Name => 'Cancelled', Id => 12402 },
                ] } },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    my ($report) = $mech->create_problems_for_body(1, $merton->id, 'Bulky collection', {
        confirmed => \'current_timestamp',
        user => $normaluser,
        category => 'Bulky collection',
        cobrand_data => 'waste',
        non_public => 1,
        extra => { payment_reference => 'reference' },
    });
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'merton',
        COBRAND_FEATURES => {
            echo => { merton => {
                url => 'https://www.example.org/',
                receive_action => 'action',
                receive_username => 'un',
                receive_password => 'password',
            } },
            waste => { merton => 1 }
        },
    }, sub {
        $mech->clear_emails_ok;
        $normaluser->create_alert($report->id, { cobrand => 'merton', whensubscribed => $date });
        my $in = $mech->echo_notify_xml('waste-12402-', 1636, 12402, '', 'FMS-' . $report->id);
        my $mech2 = $mech->clone;
        $mech2->host('merton.example.org');

        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 1, 'A new update';
        $report->discard_changes;
        is $report->state, 'cancelled', 'A state change';
        FixMyStreet::Script::Alerts::send_updates();
        my $email = $mech->get_text_body_from_email;
        like $email, qr/Cancelled/;

        $report->update({ state => 'cancelled' });

        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 1, 'No new update';
        $report->discard_changes;
        is $report->state, 'cancelled', 'No state change';
        FixMyStreet::Script::Alerts::send_updates();
        $mech->email_count_is(0);
    };
};

done_testing;
