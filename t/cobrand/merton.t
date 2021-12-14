use Test::MockModule;
use FixMyStreet::TestMech;
use HTML::Selector::Element qw(find);
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;
my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Merton');

$cobrand->mock('area_types', sub { [ 'LBO' ] });

my $merton = $mech->create_body_ok(2500, 'Merton Council', {
    api_key => 'aaa',
    jurisdiction => 'merton',
    endpoint => 'http://endpoint.example.org',
    send_method => 'Open311',
});
my @cats = ('Litter', 'Other', 'Potholes', 'Traffic lights');
for my $contact ( @cats ) {
    $mech->create_contact_ok(body_id => $merton->id, category => $contact, email => "\L$contact\@merton.example.org");
}

my $hackney = $mech->create_body_ok(2508, 'Hackney Council');
for my $contact ( @cats ) {
    $mech->create_contact_ok(body_id => $hackney->id, category => $contact, email => "\L$contact\@hackney.example.org");
}

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
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
    ALLOWED_COBRANDS => [ 'merton' ],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        anonymous_account => {
            merton => 'anonymous'
        },
    },
}, sub {

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
        is $report->user->email, 'anonymous@fixmystreet.merton.gov.uk';
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
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
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
        my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
        $ukc->mock('lookup_site_code', sub { 'USRN1234' });

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

done_testing;
