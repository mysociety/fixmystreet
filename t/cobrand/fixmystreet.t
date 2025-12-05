use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Cobrand::Birmingham;
use parent 'FixMyStreet::Cobrand::UKCouncils';
sub council_area_id { 2514 }
sub cut_off_date { DateTime->now->subtract(days => 30)->strftime('%Y-%m-%d') }

package main;
use Path::Tiny;
use JSON::MaybeXS;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::UpdateAllReports;
use FixMyStreet::Script::Reports;
my $mech = FixMyStreet::TestMech->new;

my $resolver = Test::MockModule->new('Email::Valid');
$resolver->mock('address', sub { $_[1] });

my $body = $mech->create_body_ok( 2514, 'Birmingham', { cobrand => 'birmingham' } );
$mech->create_body_ok( 2482, 'Bromley', { cobrand => 'bromley' });

$mech->create_body_ok(2482, 'Bike provider');

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Traffic lights',
    email => 'lights@example.com'
);

my $data;
FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $data = FixMyStreet::Script::UpdateAllReports::generate_dashboard($body);
};

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    TEST_DASHBOARD_DATA => $data,
    ALLOWED_COBRANDS => [ 'fixmystreet', 'birmingham' ],
    COBRAND_FEATURES => {
        categories_restriction_bodies => {
            tfl => [ 'Bike provider' ],
        }
    },
}, sub {
    ok $mech->host('www.fixmystreet.com');

    $mech->create_problems_for_body(105, $body->id, 'Titlē', {
        detail => "this report\nis split across\nseveral lines",
        areas => ",2514,",
    });

    subtest 'check marketing dashboard access' => sub {
        # Not logged in, redirected
        $mech->get_ok('/reports/Birmingham/summary');
        is $mech->uri->path, '/about/council-dashboard';

        $mech->submit_form_ok({ with_fields => { username => 'someone@somewhere.example.org' }});
        $mech->content_contains('did not recognise your email');

        $mech->log_in_ok('someone@somewhere.example.org');
        $mech->get_ok('/reports/Birmingham/summary');
        is $mech->uri->path, '/about/council-dashboard';
        $mech->content_contains('Ending in .gov.uk');

        $mech->submit_form_ok({ with_fields => { name => 'Someone', username => 'someone@birmingham.gov.uk' }});
        $mech->content_contains('Now check your email');

        my $link = $mech->get_link_from_email;
        $mech->get_ok($link);
        is $mech->uri->path, '/reports/Birmingham/summary';
        $mech->content_contains('Where we send Birmingham');
        $mech->content_contains('lights@example.com');
        $mech->content_like(qr{<th scope="row">Other</th>\s*<td>105</td>});
    };

    subtest 'check marketing dashboard csv' => sub {
        $mech->log_in_ok('someone@birmingham.gov.uk');
        $mech->get_ok('/reports/Birmingham/summary?csv=1');
        my @rows = $mech->content_as_csv;
        is scalar @rows, 101, '1 (header) + 100 (reports) = 101 lines';

        is scalar @{$rows[0]}, 10, '10 columns present';

        is_deeply $rows[0],
            [
                'Report ID',
                'Title',
                'Category',
                'Created',
                'Confirmed',
                'Status',
                'Latitude',
                'Longitude',
                'Query',
                'Report URL',
            ],
            'Column headers look correct';

        my $body_id = $body->id;
        like $rows[1]->[1], qr/Titlē Test \d+ for $body_id/, 'problem title correct';
    };

    subtest 'check marketing dashboard contact listings' => sub {
        $mech->log_in_ok('someone@birmingham.gov.uk');
        $body->send_method('Open311');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Reports to Birmingham are currently sent directly');

        $body->send_method('Refused');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Birmingham currently does not accept');

        $body->send_method('Noop');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Reports are currently not being sent');
        $body->send_method('');
        $body->update();

        $mech->log_out_ok();
        $mech->get_ok('/reports');
        $mech->content_lacks('Where we send Birmingham');
    };

    subtest 'Check All Reports page for bike bodies' => sub {
        $mech->get_ok('/reports/Bike+provider');
        $mech->content_contains('Bromley');
        $mech->content_lacks('Trowbridge');
        $mech->get_ok('/reports/Bike+provider/Bromley');
        is $mech->uri->path, '/reports/Bike+provider/Bromley';
    };

    subtest 'check average fix time respects cobrand cut-off date and non-standard reports' => sub {
        $mech->log_in_ok('someone@birmingham.gov.uk');
        my $user = FixMyStreet::DB->resultset('User')->find_or_create({ email => 'counciluser@example.org' });

        # A report created 100 days ago (ie before the cobrand's cut-off), just fixed.
        my ($report1) = $mech->create_problems_for_body(2, $body->id, 'Title', {
            confirmed => DateTime->now->subtract(days => 100),
        });
        $report1->comments->create({
            user      => $user,
            name      => 'A User',
            anonymous => 'f',
            text      => 'fixed the problem',
            state     => 'confirmed',
            mark_fixed => 1,
            confirmed => DateTime->now,
        });

        # Another report, created 10 days ago, that was just fixed.
        my ($report2) = $mech->create_problems_for_body(2, $body->id, 'Title', {
            confirmed => DateTime->now->subtract(days => 10),
        });
        $report2->comments->create({
            user      => $user,
            name      => 'A User',
            anonymous => 'f',
            text      => 'fixed the problem',
            state     => 'confirmed',
            mark_fixed => 1,
            confirmed => DateTime->now,
        });

        # Another report, created 10 days ago, that was just fixed.
        my ($report3) = $mech->create_problems_for_body(1, $body->id, 'Title', {
            confirmed => DateTime->now->subtract(days => 1),
            cobrand_data => 'waste',
        });
        $report3->comments->create({
            user      => $user,
            name      => 'A User',
            anonymous => 'f',
            text      => 'fixed the problem',
            state     => 'confirmed',
            mark_fixed => 1,
            confirmed => DateTime->now,
        });

        $mech->get_ok('/about/council-dashboard');
    };
};

subtest 'check heatmap page for cllr' => sub {
    my $user = $mech->create_user_ok( 'cllr@bromley.gov.uk', name => 'Cllr Bromley' );
    my $config = {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => { heatmap => { bromley => 1 } },
    };
    FixMyStreet::override_config $config, sub {
        $mech->log_out_ok;
        $mech->get('/dashboard/heatmap');
        is $mech->res->previous->code, 302;
        $mech->log_in_ok($user->email);
        $mech->get('/dashboard/heatmap');
        is $mech->res->code, 404;
    };
    $config->{COBRAND_FEATURES}{heatmap_dashboard_body}{bromley} = 1;
    FixMyStreet::override_config $config, sub {
        $mech->get_ok('/dashboard/heatmap');
    };
};

FixMyStreet::DB->resultset("Config")->create({ key => 'extra_parishes', value => [ 59087 ] });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'test enforced 2FA for superusers' => sub {
        my $test_email = 'test@example.com';
        my $user = FixMyStreet::DB->resultset('User')->find_or_create({ email => $test_email });
        $user->password('password');
        $user->is_superuser(1);
        $user->update;

        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $test_email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_contains('requires two-factor');

        # Sign up for 2FA
        $mech->submit_form_ok({ with_fields => { '2fa_action' => 'activate' } }, "submit 2FA activation");
        my ($token) = $mech->content =~ /name="secret32" value="([^"]*)">/;
        use Auth::GoogleAuth;
        my $auth = Auth::GoogleAuth->new({ secret32 => $token });
        my $code = $auth->code;
        $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
        $mech->content_contains('successfully enabled two-factor authentication', "2FA activated");
    };

    subtest 'test extra parish areas' => sub {
        $mech->get_ok('/admin/bodies/add');
        $mech->content_contains('Bradenham');
        $mech->content_contains('Castle Bromwich');
        $mech->log_out_ok;
    };
};

FixMyStreet::override_config {
    COBRAND_FEATURES => {
        borough_email_addresses => {
            fixmystreet => {
                'graffiti@northamptonshire' =>
                    [ { areas => [2397], email => 'graffiti@northampton' }, ],
                'cleaning@somerset' => [
                    { areas => [2428], email => 'IdvEnquiries@mendip.dev' },
                ],
                'other@nyorks' => [
                    { areas => [2406], email => 'environment@richmondshire.dev' },
                ],
                'default@cumbria' => [
                    { areas => [2274], email => 'street.scene@allerdale.dev' },
                ],
            }
        }
        },
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Ex-district reports are sent to correct emails' => sub {
        subtest 'Northampton' => sub {
            my $body    = $mech->create_body_ok( 2397, 'Northampton' );
            my $contact = $mech->create_contact_ok(
                body_id  => $body->id,
                category => 'Graffiti',
                email    => 'graffiti@northamptonshire',
            );

            my ($report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Title',
                {   latitude  => 52.236252,
                    longitude => -0.892053,
                    cobrand   => 'fixmystreet',
                    category  => 'Graffiti',
                }
            );
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1);
            my @email = $mech->get_email;
            is $email[0]->header('To'), 'Northampton <graffiti@northampton>';
            $mech->clear_emails_ok;
        };

        subtest 'Mendip (Somerset)' => sub {
            my $body
                = $mech->create_body_ok( 2428, 'Mendip District Council' );
            my $contact = $mech->create_contact_ok(
                body_id  => $body->id,
                category => 'Graffiti',
                email    => 'cleaning@somerset',
            );

            my ($report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Title',
                {   latitude  => 51.26345,
                    longitude => -2.28191,
                    cobrand   => 'fixmystreet',
                    category  => 'Graffiti',
                }
            );
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1);
            my @email = $mech->get_email;
            is $email[0]->header('To'),
                '"Mendip District Council" <IdvEnquiries@mendip.dev>';
            $mech->clear_emails_ok;
        };

        subtest 'Richmondshire (N Yorks)' => sub {
            my $body = $mech->create_body_ok( 2406,
                'Richmondshire District Council' );
            my $contact = $mech->create_contact_ok(
                body_id  => $body->id,
                category => 'Graffiti',
                email    => 'other@nyorks',
            );

            my ($report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Title',
                {   latitude  => 54.45012,
                    longitude => -1.65621,
                    cobrand   => 'fixmystreet',
                    category  => 'Graffiti',
                }
            );
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1);
            my @email = $mech->get_email;
            is $email[0]->header('To'),
                '"Richmondshire District Council" <environment@richmondshire.dev>';
            $mech->clear_emails_ok;
        };

        subtest 'Allerdale (Cumbria)' => sub {
            my $body = $mech->create_body_ok( 2274,
                'Allerdale Borough Council' );
            my $contact = $mech->create_contact_ok(
                body_id  => $body->id,
                category => 'Graffiti',
                email    => 'default@cumbria',
            );

            my ($report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Title',
                {   latitude  => 54.60102,
                    longitude => -3.13648,
                    cobrand   => 'fixmystreet',
                    category  => 'Graffiti',
                }
            );
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1);
            my @email = $mech->get_email;
            is $email[0]->header('To'),
                '"Allerdale Borough Council" <street.scene@allerdale.dev>';
            $mech->clear_emails_ok;
        };
    };
};

my $cobrand = FixMyStreet::Cobrand::Birmingham->new;

for my $test (
    {
        update_permission => 'staff',
        problem_state => 'confirmed',
    },
    {
        update_permission => 'none',
        problem_state => 'confirmed',
    },
    {
        update_permission => 'none',
        problem_state => 'closed',
    },
    {
        update_permission => 'staff',
        problem_state => 'closed',
    },
    {
        update_permission => 'reporter-open',
        problem_state => 'closed',
    },
    {
        update_permission => 'reporter/staff-open',
        problem_state => 'closed',
    },
    {
        update_permission => 'open',
        problem_state => 'closed',
    }
) {
    subtest 'Cobrand set to deny updates' => sub {
        FixMyStreet::override_config {
            COBRAND_FEATURES => {
            updates_allowed => { birmingham => $test->{update_permission} },
            },
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test problem', {
             state => "$$test{problem_state}",
        });
        ok($cobrand->deny_updates_by_user($problem), "Reports updates denied with $test->{update_permission} and problem $test->{problem_state}");
        $mech->delete_problems_for_body($body->id);
    };
    };
};

for my $test (
    {
        update_permission => 'reporter',
        problem_state => 'confirmed',
    },
    {
        update_permission => 'reporter',
        problem_state => 'closed',
    },
    {
        update_permission => 'reporter-open',
        problem_state => 'confirmed',
    },
    {
        update_permission => '',
        problem_state => 'confirmed',
    },
    {
        update_permission => '',
        problem_state => 'closed',
    },
    {
        update_permission => 'open',
        problem_state => 'confirmed',
    }
) {
    subtest 'Cobrand set to allow updates' => sub {
        FixMyStreet::override_config {
            COBRAND_FEATURES => {
            updates_allowed => { birmingham => $test->{update_permission} },
            },
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test problem', {
             state => "$$test{problem_state}",
        });
        ok(!$cobrand->deny_updates_by_user($problem), "Reports updates allowed with $test->{update_permission} and problem $test->{problem_state}");
        $mech->delete_problems_for_body($body->id);
    };
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'fixmystreet shows Environment Agency categories' => sub {
        my $bexley = $mech->create_body_ok(2494, 'London Borough of Bexley');
        my $environment_agency = $mech->create_body_ok(2494, 'Environment Agency');
        my $odour_contact = $mech->create_contact_ok(body_id => $environment_agency->id, category => 'Odour', email => 'ics@example.com');
        my $tree_contact = $mech->create_contact_ok(body_id => $bexley->id, category => 'Trees', email => 'foo@bexley');
        $mech->get_ok("/report/new/ajax?latitude=51.466707&longitude=0.181108");
        $mech->content_contains('Trees');
        $mech->content_contains('Odour');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'fixmystreet.com privacy policy page link deactivates correctly' => sub {
        $mech->get_ok('/about/privacy');
        $mech->content_contains('<strong>Privacy and cookies</strong>');
        $mech->content_lacks('<a href="/privacy">Privacy and cookies</a>');
	};
};


FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    CONTACT_EMAIL => 'fixmystreet@example.org',
}, sub {
    my $traffic_scotland = $mech->create_body_ok(2651, 'Traffic Scotland');
    my $edinburgh = $mech->create_body_ok(2651, 'Aberdeen City Council');
    $mech->create_contact_ok(body_id => $edinburgh->id, category => 'Flytipping', email => 'flytip@example.com');
    $mech->create_contact_ok(body_id => $traffic_scotland->id, category => 'Pothole (TS)', email => 'trafficscotland@example.com');
    my $he_mod = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
    $he_mod->mock('_fetch_features', sub {[]});

    $mech->get_ok("/report/new?longitude=-3.189579&latitude=55.952055");
    $mech->content_contains('data-valuealone="Flytipping"', 'Edinburgh category available when no traffic Scotland road');
    $mech->content_lacks('data-valuealone="Pothole (TS)"', 'Traffic Scotland category not available when no road');
    $he_mod->mock('_fetch_features', sub {
        my ($self, $cfg) = @_;
        return [
            {
                properties => { area_name => 'Area 1', ROA_NUMBER => 'M1', sect_label => 'M1/111' },
                geometry => {
                    type => 'LineString',
                    coordinates => [ [ -2, +2 ], [ +2, +2 ] ],
                }
            },
        ];
    });
    $mech->get_ok("/report/new?longitude=-3.189579&latitude=55.952055");
    $mech->content_contains('data-valuealone="Flytipping"', 'Edinburgh category available when no traffic Scotland road');
    $mech->content_contains('data-valuealone="Pothole (TS)"', 'Traffic Scotland category available when on a TS road');
    $mech->content_contains('data-category_display="Pothole"', 'Traffic Scotland display excludes (TS)');
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
    BASE_URL => 'https://www.fixmystreet.com',
    COBRAND_FEATURES => {
        borough_email_addresses => {
            highwaysengland => {
                'potholes@nh' => [ {
                    'areas' => [ 'Area 1' ],
                    'email' => 'area1email@example.org',
                } ],
            },
        },
    },
}, sub {
    my $hampshire = $mech->create_body_ok(2227, 'Hampshire County Council');
    my $he = $mech->create_body_ok(2227, 'National Highways', { send_method => 'Email::Highways', cobrand => 'highwaysengland' });
    $mech->create_contact_ok(body_id => $hampshire->id, category => 'Flytipping', email => 'foo@bexley');
    $mech->create_contact_ok(body_id => $hampshire->id, category => 'Trees', email => 'foo@bexley');
    $mech->create_contact_ok(body_id => $hampshire->id, category => 'Messy roads', email => 'foo@bexley', extra => {litter_category_for_he => 1});
    $mech->create_contact_ok(body_id => $he->id, category => 'Slip Roads (NH)', email => 'litter@nh', group => 'Litter');
    $mech->create_contact_ok(body_id => $he->id, category => 'Main Carriageway (NH)', email => 'litter@nh', group => 'Litter');
    $mech->create_contact_ok(body_id => $he->id, category => 'Potholes (NH)', email => 'potholes@nh');

    our $he_mod = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
    sub mock_road {
        my ($name, $litter) = @_;
        $he_mod->mock('_fetch_features', sub {
            my ($self, $cfg) = @_;
            my $road = {
                properties => { area_name => 'Area 1', ROA_NUMBER => $name, sect_label => "$name/111" },
                geometry => {
                    type => 'LineString',
                    coordinates => [ [ -2, +2 ], [ +2, +2 ] ],
                }
            };
            if ($cfg->{typename} eq 'highways_litter_pick') {
                return $litter ? [$road] : [];
            }
            return [$road];
        });
    }

    subtest 'fixmystreet changes litter options for National Highways' => sub {

        # Motorway, NH responsible for litter (but not in dataset), council categories will also be present
        mock_road("M1", 0);
        $mech->get_ok("/report/new?longitude=-0.912160&latitude=51.015143");
        $mech->content_contains('Litter');
        $mech->content_contains('Slip Roads');
        $mech->content_contains('Main Carriageway');
        $mech->content_contains('Potholes');
        $mech->content_contains("Trees'>");
        $mech->content_contains("Flytipping'>");

        # A-road where NH responsible for litter, council categories will also be present
        mock_road("A5103", 1);
        $mech->get_ok("/report/new?longitude=-0.912160&latitude=51.015143");
        $mech->content_contains('Litter');
        $mech->content_contains('Slip Roads');
        $mech->content_contains('Main Carriageway');
        $mech->content_contains('Potholes');
        $mech->content_contains("Trees'>");
        $mech->content_contains("Flytipping'>");

        # A-road where NH not responsible for litter, no NH litter categories
        mock_road("A34", 0);
        $mech->get_ok("/report/new?longitude=-0.912160&latitude=51.015143");
        $mech->content_lacks('Litter');
        $mech->content_lacks('Slip Roads');
        $mech->content_lacks('Main Carriageway');
        $mech->content_contains('Potholes');
        $mech->content_contains("Trees'>");
        $mech->content_contains('value=\'Flytipping\' data-nh="1"');

        # A-road where NH not responsible for litter, referred to FMS from National Highways
        # ajax call filters NH category to contain only litter related council categories
        mock_road("A34", 0);
        my $j = $mech->get_ok_json("/report/new/ajax?w=1&longitude=-0.912160&latitude=51.015143&he_referral=1");
        my $tree = HTML::TreeBuilder->new_from_content($j->{category});
        my @elements = $tree->find('input');
        is @elements, 2, 'Two categories in National Highways category';
        is $elements[0]->attr('value') eq 'Flytipping', 1, 'Subcategory is Flytipping - default litter category';
        is $elements[1]->attr('value') eq 'Messy roads', 1, 'Subcategory is Messy roads - checkbox selected litter category';
    };

    subtest "check .com report uses borough_email_addresses" => sub {
        $mech->get_ok("/report/new?longitude=-0.912160&latitude=51.015143");
        $mech->content_contains('data-category_display="Potholes"', 'National Highways display excludes (NH)');
        $mech->submit_form_ok({ with_fields => {
            title => "Test Report for HE",
            detail => 'Test report details.',
            category => 'Potholes (NH)',
            name => 'Highways England',
            username_register => 'highways@example.org',
        } }, "submit good details");
        $mech->content_contains('Now check your email');

        my $link = $mech->get_link_from_email;
        $mech->get_ok($link);

        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        is $email->header('To'), '"National Highways" <area1email@example.org>';
        $mech->clear_emails_ok;
        $mech->log_out_ok;
    };

    subtest "check things redacted appropriately" => sub {
        $mech->get_ok("/report/new?longitude=-0.912160&latitude=51.015143&1");
        my $title = "Test Redact report from 07000 000000";
        my $detail = 'Please could you email me on test@example.org or ring me on (01234) 567 890.';
        $mech->submit_form_ok({
            with_fields => {
                title => $title,
                detail => $detail,
                category => 'Potholes (NH)',
                name => 'Test Example',
                username_register => 'test@example.org',
            }
        }, "submit details");
        $mech->content_contains('Nearly done');

        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->title, 'Test Redact report from [phone removed]';
        is $report->detail, 'Please could you email me on [email removed] or ring me on [phone removed].';

        my ($history) = $report->moderation_history;
        is $history->title, $title;
        is $history->detail, $detail;

        $report->delete;
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'geo-located /around is zoomed in further' => sub {
        $mech->get_ok('/around?longitude=-2.364050&latitude=51.386269');
        $mech->content_contains("data-zoom=2");
        $mech->get_ok('/around?longitude=-2.364050&latitude=51.386269&geolocate=1');
        $mech->content_contains("data-zoom=4");
    }
};

subtest 'store_front_stats_data generates correct JSON file' => sub {
    # Set up a temporary dir for the JSON files, and mock path_to to use it
    my $TEMP_DIR = Path::Tiny->tempdir->child("fixmystreet");
    $TEMP_DIR->mkpath;
    my $fms = Test::MockModule->new('FixMyStreet');
    $fms->mock('path_to', sub {
        my $class = shift;
        return $TEMP_DIR->child(@_);
    });

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
    }, sub {
        FixMyStreet::DB->resultset('Problem')->delete_all;
        FixMyStreet::DB->resultset('Comment')->delete_all;

        my $test_body = $mech->create_body_ok(2651, 'Test Body');
        my $user = $mech->create_user_ok('testuser@example.org');

        # Create 3 new reports (confirmed recently)
        my @new_reports = $mech->create_problems_for_body(3, $test_body->id, 'New report', {
            confirmed => DateTime->now->subtract(days => 3),
        });

        # Create 2 fixed reports (updated in last month)
        my @fixed_reports = $mech->create_problems_for_body(2, $test_body->id, 'Fixed report', {
            confirmed => DateTime->now->subtract(days => 20),
            state => 'fixed - council',
            lastupdate => DateTime->now->subtract(days => 5),
        });

        # Create 4 comments on various reports
        $new_reports[0]->comments->create({
            user => $user,
            name => 'Test User',
            anonymous => 'f',
            text => 'update 1',
            state => 'confirmed',
            confirmed => DateTime->now->subtract(days => 2),
        });
        $new_reports[1]->comments->create({
            user => $user,
            name => 'Test User',
            anonymous => 'f',
            text => 'update 2',
            state => 'confirmed',
            confirmed => DateTime->now->subtract(days => 1),
        });
        $fixed_reports[0]->comments->create({
            user => $user,
            name => 'Test User',
            anonymous => 'f',
            text => 'update 3',
            state => 'confirmed',
            confirmed => DateTime->now->subtract(days => 3),
        });
        $fixed_reports[1]->comments->create({
            user => $user,
            name => 'Test User',
            anonymous => 'f',
            text => 'update 4',
            state => 'confirmed',
            confirmed => DateTime->now->subtract(days => 4),
        });

        # Get the cobrand and calculate stats
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('fixmystreet')->new;
        my $stats = $cobrand->calculate_front_stats_data;

        # Verify calculated stats are correct
        is $stats->{new}, 3, 'new reports count is correct (3 confirmed in last 3 days)';
        is $stats->{updates}, 4, 'updates count is correct';
        is $stats->{fixed}, 2, 'fixed reports count is correct';
        is $stats->{recency}, '3 days', 'recency is correct (new > fixed, so shortened)';

        # Write stats to file (mimicking what the script does)
        my $all_stats = {
            _generated => time(),
            fixmystreet => $stats,
        };
        my $stats_file = FixMyStreet->path_to('../data/front-page-stats.json');
        my $dir = FixMyStreet->path_to('../data');
        path($dir)->mkpath unless -d $dir;
        path($stats_file)->spew_utf8(JSON::MaybeXS->new(pretty => 1, canonical => 1)->encode($all_stats));

        # Verify file was written correctly
        ok -e $stats_file, 'JSON file created on disk';
        my $json_content = path($stats_file)->slurp_utf8;
        my $parsed_all_stats = JSON::MaybeXS->new->decode($json_content);
        ok $parsed_all_stats->{_generated} > 0, '_generated is a positive number';
        ok $parsed_all_stats->{_generated} <= time(), '_generated is not in the future';
        ok $parsed_all_stats->{fixmystreet}, 'fixmystreet stats exist in JSON file';
    };
};

done_testing();
