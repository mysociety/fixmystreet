use FixMyStreet::TestMech;
use Test::MockModule;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech    = FixMyStreet::TestMech->new;
my $cobrand = FixMyStreet::Cobrand::CanalRiverTrust->new;
my $body    = $mech->create_body_ok(
    2226, # Same as for Gloucestershire for testing purposes
    'Canal & River Trust',
    {   send_method  => 'Email',
        cobrand => 'canalrivertrust',
    },
);

my $bad_boat = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Bad boat (CRT: ABC)',
    email => 'bad_boat@crt.dev',
);

my $standard_user_1
    = $mech->create_user_ok( 'user1@email.com', name => 'User 1' );
my $standard_user_2
    = $mech->create_user_ok( 'user2@email.com', name => 'User 2' );
my $staff_user = $mech->create_user_ok(
    'staff@email.com',
    name      => 'Staff User',
    from_body => $body,
);

$staff_user->user_body_permissions->create({ body => $body, permission_type => 'category_edit' });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet', 'canalrivertrust' ],
    MAPIT_URL        => 'http://mapit.uk/',
    STAGING_FLAGS    => { skip_must_have_2fa => 1 },
    COBRAND_FEATURES => {
        update_states_disallowed => {
            canalrivertrust => 1,
            fixmystreet => {
                'Canal & River Trust' => 1,
            },
        },
        updates_allowed   => {
            canalrivertrust => 'none',
            fixmystreet     => {
                'Canal & River Trust' => 'none',
            }
        },
    },
}, sub {
    my ($report) = $mech->create_problems_for_body(
        1,
        $body->id,
        'My report',
        {   cobrand => 'canalrivertrust',
            user    => $standard_user_1,
            category => 'Bad boat',
        },
    );

    for my $host ( qw/fixmystreet canalrivertrust/ ) {
        ok $mech->host($host), "change host to $host";

        for my $user ( undef, $standard_user_1, $standard_user_2, $staff_user ) {
            $user ? $mech->log_in_ok( $user->email ) : $mech->log_out_ok;

            # No-one can leave an update on an open report
            $report->update( { state => 'in progress' } );

            $mech->get_ok( '/report/' . $report->id );
            $mech->content_lacks( 'Provide an update',
                'Cannot leave update on open report' );

            # Nobody can mark report as fixed
            $mech->content_lacks( 'This problem has been fixed',
                'Cannot mark report as fixed' );

            # No option to reopen report
            $report->update( { state => 'fixed' } );

            $mech->get_ok( '/report/' . $report->id );
            $mech->content_lacks(
                'This problem has not been fixed',
                'No option to reopen report',
            );

            # No-one can leave update on a closed report
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_lacks( 'Provide an update',
                'Cannot leave update on closed report' );
        }
    }

    $mech->log_in_ok( $standard_user_1->email );
    ok $mech->host('canalrivertrust');
    $mech->get_ok('/report/new?longitude=-2.2458&latitude=51.86506');

    $mech->text_contains('Bad boat', 'Display name');
    $mech->text_lacks('Bad boat (CRT: ABC)', 'Original name not displayed');

    # click through to the report page
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, } );
    $mech->submit_form_ok(
        {   button      => 'submit_register',
            with_fields => {
                category => 'Bad boat (CRT: ABC)',
                detail   => 'Test report details',
                title    => 'Test Report',
            }
        }
    );

    $bad_boat->discard_changes;
    is $bad_boat->get_extra_metadata('display_name'), undef,
        'Category display name not saved';

    $report
        = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
    $mech->get_ok( '/report/' . $report->id );
    $mech->text_like( qr/Reported.*in the Bad boat category/,
        'Display name used in meta line' );
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'canalrivertrust' ],
    MAPIT_URL        => 'http://mapit.uk/',
    COBRAND_FEATURES => {
    },
}, sub {
    $mech->get_ok( '/reports' );
    $mech->content_contains('Get updates of reports on the Canal & River Trust');
    $mech->content_lacks('class="has-inline-svg">Wards of this council');
    $mech->content_contains('href="/rss/reports/Canal+&amp;+River+Trust"');
    $mech->get_ok( '/rss/reports/Canal+&+River+Trust' ); # Browser decoded &amp;
    $mech->content_contains('New problems to Canal &amp; River Trust on Canal &amp; River Trust');
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'canalrivertrust' ],
    MAPIT_URL => 'http://mapit.uk/',
    BASE_URL => 'http://www.example.org',
    COBRAND_FEATURES => {
        category_groups => { canalrivertrust => 1 },
    }
}, sub {
    subtest 'Displays and protects category names' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/admin/body/' . $body->id);
        $mech->follow_link_ok({ text => 'Add new category' });
        $mech->content_contains('Parent categories');
        $mech->submit_form_ok( { with_fields => {
                category => 'Access issues (CRT)',
                group => 'Aqueduct',
                email => 'AccessIssues@test.com',
            }
        });
        $mech->content_contains('Category must end with (CRT: &lt;group_name&gt;)');
        $mech->submit_form_ok( { with_fields => {
                category => 'Access issues (CRT: Aqueduct)',
                group => 'Aqueduct',
                email => 'AccessIssues@test.com',
            }
        });
        $mech->content_contains('New category contact added');

        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR' } },
            'submit location' );
        $mech->follow_link_ok(
            { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link"
        );

        $mech->content_contains('data-category_display="Access issues"');
    };
};

subtest 'open311_update_missing_data' => sub {
    my $ukc_mock = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');

    my ($report) = $mech->create_problems_for_body( 1, $body, 'Title', {
        latitude => '51.53586',
        longitude => '-0.103714',
    } );

    subtest 'no nearby features' => sub {
        $ukc_mock->mock('_fetch_features', sub {});

        $cobrand->open311_update_missing_data($report);

        is $report->get_extra_field_value('region_c'), undef;
    };

    subtest 'nearby features' => sub {
        $ukc_mock->mock( '_fetch_features', &_fetch_features_mock );

        subtest 'nearest correctly selected' => sub {
            $cobrand->open311_update_missing_data($report);

            is $report->get_extra_field_value('region_c'), 'London & South East';
        };

        subtest 'report already has region_c' => sub {
            $report->update_extra_field({
                name => 'region_c',
                value => 'Another region',
            });

            $cobrand->open311_update_missing_data($report);

            is $report->get_extra_field_value('region_c'), 'Another region';
        };
    };
};

sub _fetch_features_mock {
    [   {   'ms:Canals' => {
                'gml:boundedBy' => {
                    'gml:Envelope' => {
                        'gml:lowerCorner' => '531616.254800 183238.263300',
                        'gml:upperCorner' => '532513.142900 183556.587100',
                        'srsName'         => 'EPSG:27700'
                    }
                },
                'gml:id'        => 'Canals.2039',
                'ms:OBJECTID'   => '2039',
                'ms:functional' => 'RE-008',
                'ms:msGeometry' => {
                    'gml:LineString' => {
                        'gml:posList' => {
                            'content' =>
                                '532513.142900 183556.587100 532533.079300 183571.671500 532547.197800 183582.353800 532553.015700 183586.755900 532572.949200 183601.838600 532592.808500 183617.030100 532597.070700 183620.290500 532607.801200 183629.891600 532611.702500 183633.382200 532626.692000 183646.793700 532630.574000 183649.761700 532650.434300 183664.945900 532662.700700 183674.324300 532670.132900 183680.336000 532689.570300 183696.058400 532709.318700 183712.032500 532728.741700 183727.128600 532743.693900 183738.742200 532748.547900 183742.382500 532759.570000 183750.648700 532770.428400 183756.681300 532785.250100 183763.874400 532791.632600 183767.466600 532798.187700 183771.156000 532805.509300 183772.789400 532815.514300 183774.730600 532840.011200 183779.806700 532864.212500 183785.072200 532888.430000 183790.341600 532912.106900 183795.261900 532937.095800 183800.354900 532948.213300 183802.592900 532956.062200 183804.172000 532962.529100 183804.081700 532968.684500 183803.215800 532986.848400 183799.716700 533011.397200 183794.987600 533024.964100 183792.374100 533035.930600 183790.181400 533060.445400 183785.279900 533084.960100 183780.378300 533089.263200 183779.517900 533109.519200 183775.704300 533133.733500 183771.139300 533158.572000 183766.027200 533183.058700 183760.987600 533192.457800 183759.053200 533207.646900 183756.489400 533232.297900 183752.328500 533256.949400 183748.167000 533270.685600 183745.848100 533281.586800 183743.925800 533294.274900 183741.688500 533306.068600 183738.911100 533310.440400 183737.881600 533331.537100 183732.912800 533354.736700 183727.448500 533358.753600 183726.502400 533373.624300 183723.000500 533379.137400 183722.041500 533405.105000 183717.524300 533428.481300 183713.458000 ',
                            'srsDimension' => '2'
                        },
                        'srsName' => 'EPSG:27700'
                    }
                },
                'ms:name'   => 'Regent\'s Canal',
                'ms:region' => 'North West'
            }
        },
        {   'ms:Canals' => {
                'gml:boundedBy' => {
                    'gml:Envelope' => {
                        'gml:lowerCorner' => '530631.480900 183305.258700',
                        'gml:upperCorner' => '531616.254800 183473.923500',
                        'srsName'         => 'EPSG:27700'
                    }
                },
                'gml:id'        => 'Canals.2040',
                'ms:OBJECTID'   => '2040',
                'ms:functional' => 'RE-009',
                'ms:msGeometry' => {
                    'gml:LineString' => {
                        'gml:posList' => {
                            'content' =>                                '530631.480900 183473.923500 530635.322600 183473.383000 530650.069300 183471.700600 530656.320700 183471.122600 530664.770800 183470.341200 530677.749800 183469.140700 530682.161100 183469.463400 530691.442000 183469.776500 530698.100800 183469.010200 530706.087600 183468.088100 530709.000600 183467.265700 530719.249100 183463.749600 530730.325900 183462.351500 530733.480200 183461.953400 530755.127100 183459.204700 530763.887200 183458.092300 530779.925800 183456.038100 530805.542700 183452.757100 530829.579400 183450.187900 530836.714900 183449.430600 530848.428800 183447.699100 530854.312200 183446.610800 530878.895200 183442.063400 530903.478200 183437.516100 530928.061000 183432.968800 530952.644000 183428.421400 530977.227000 183423.874100 531001.810100 183419.326700 531026.392900 183414.779400 531051.965900 183410.048900 531075.555800 183405.668700 531100.135600 183401.104100 531124.715400 183396.539500 531149.295200 183391.974900 531173.874900 183387.410300 531198.454700 183382.845700 531223.034500 183378.281100 531247.684800 183373.703400 531272.194000 183369.152000 531296.773800 183364.587500 531321.353600 183360.023000 531345.933300 183355.458500 531370.513100 183350.894000 531395.092900 183346.329500 531419.672700 183341.765000 531445.559600 183336.957800 531468.832100 183332.635400 531475.170000 183331.458300 531493.411800 183328.070800 531517.991600 183323.506300 531542.571400 183318.941800 531567.151200 183314.377300 531591.730900 183309.812800 531616.254800 183305.258700 ',
                            'srsDimension' => '2'
                        },
                        'srsName' => 'EPSG:27700'
                    }
                },
                'ms:name'   => 'Regent\'s Canal',
                'ms:region' => 'London & South East'
            }
        }
    ];
}

done_testing();
