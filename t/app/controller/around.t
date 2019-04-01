package FixMyStreet::Map::Tester;
use base 'FixMyStreet::Map::FMS';

use constant ZOOM_LEVELS    => 99;
use constant MIN_ZOOM_LEVEL => 88;

1;

package main;

use Test::MockModule;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

subtest "check that if no query we get sent back to the homepage" => sub {
    $mech->get_ok('/around');
    is $mech->uri->path, '/', "redirected to '/'";
};

# test various locations on inital search box
foreach my $test (
    {
        pc              => '',    #
        errors          => [],
        pc_alternatives => [],
    },
    {
        pc              => 'xxxxxxxxxxxxxxxxxxxxxxxxxxx',
        errors          => ['Sorry, we could not find that location.'],
        pc_alternatives => [],
    },
    {
        pc => 'Glenthorpe Ct, Katy, TX 77494, USA',
        errors =>
          ['Sorry, we could not find that location.'],
        pc_alternatives => [],
    },
  )
{
    subtest "test bad pc value '$test->{pc}'" => sub {
        $mech->get_ok('/');
        FixMyStreet::override_config {
            GEOCODER => '',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
                "bad location" );
        };
        is_deeply $mech->page_errors, $test->{errors},
          "expected errors for pc '$test->{pc}'";
        is_deeply $mech->pc_alternatives, $test->{pc_alternatives},
          "expected alternatives for pc '$test->{pc}'";
    };
}

# check that exact queries result in the correct lat,lng
foreach my $test (
    {
        pc        => 'SW1A 1AA',
        latitude  => '51.501009',
        longitude => '-0.141588',
    },
    {
        pc        => 'TQ 388 773',
        latitude  => '51.478074',
        longitude => '-0.001966',
    },
  )
{
    subtest "check lat/lng for '$test->{pc}'" => sub {
        $mech->get_ok('/');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
                "good location" );
        };
        is_deeply $mech->page_errors, [], "no errors for pc '$test->{pc}'";
        is_deeply $mech->extract_location, $test,
          "got expected location for pc '$test->{pc}'";
    };
}

my $body_edin_id = $mech->create_body_ok(2651, 'City of Edinburgh Council')->id;
my $body_west_id = $mech->create_body_ok(2504, 'Westminster City Council')->id;

my @edinburgh_problems = $mech->create_problems_for_body( 5, $body_edin_id, 'Around page', {
    postcode  => 'EH1 1BB',
    latitude  => 55.9519637512,
    longitude => -3.17492254484,
});

subtest 'check lookup by reference' => sub {
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => 'ref:12345' } }, 'bad ref');
    $mech->content_contains('Searching found no reports');
    my $id = $edinburgh_problems[0]->id;
    $mech->submit_form_ok( { with_fields => { pc => "ref:$id" } }, 'good ref');
    is $mech->uri->path, "/report/$id", "redirected to report page";
};

subtest 'check non public reports are not displayed on around page' => sub {
    $mech->get_ok('/');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
            "good location" );
    };
    $mech->content_contains( "Around page Test 3 for $body_edin_id",
        'problem to be marked non public visible' );

    my $private = $edinburgh_problems[2];
    ok $private->update( { non_public => 1 } ), 'problem marked non public';

    $mech->get_ok('/');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
            "good location" );
    };
    $mech->content_lacks( "Around page Test 3 for $body_edin_id",
        'problem marked non public is not visible' );
};

for my $permission ( qw/ report_inspect report_mark_private/ ) {
    subtest 'check non public reports are displayed on around page with $permission permission' => sub {
        my $body = FixMyStreet::DB->resultset('Body')->find( $body_edin_id );
        my $body2 = FixMyStreet::DB->resultset('Body')->find( $body_west_id );
        my $user = $mech->log_in_ok( 'test@example.com' );
        $user->user_body_permissions->delete();
        $user->update({ from_body => $body });
        $user->user_body_permissions->find_or_create({
            body => $body,
            permission_type => $permission,
        });

        $mech->get_ok('/');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
                "good location" );
        };
        $mech->content_contains( "Around page Test 3 for $body_edin_id",
            'problem marked non public is visible' );
        $mech->content_contains( "Around page Test 2 for $body_edin_id",
            'problem marked public is visible' );

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/around?pc=EH1+1BB&status=non_public');
        };
        $mech->content_contains( "Around page Test 3 for $body_edin_id",
            'problem marked non public is visible' );
        $mech->content_lacks( "Around page Test 2 for $body_edin_id",
            'problem marked public is not visible' );

        $user->user_body_permissions->delete();
        $user->update({ from_body => $body2 });
        $user->user_body_permissions->find_or_create({
            body => $body2,
            permission_type => $permission,
        });

        $mech->get_ok('/');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
                "good location" );
        };
        $mech->content_lacks( "Around page Test 3 for $body_edin_id",
            'problem marked non public is not visible' );
        $mech->content_contains( "Around page Test 2 for $body_edin_id",
            'problem marked public is visible' );

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/around?pc=EH1+1BB&status=non_public');
        };
        $mech->content_lacks( "Around page Test 3 for $body_edin_id",
            'problem marked non public is not visible' );
        $mech->content_lacks( "Around page Test 2 for $body_edin_id",
            'problem marked public is visible' );
    };
}

my $body = $mech->create_body_ok(2237, "Oxfordshire");

subtest 'check category, status and extra filtering works on /around' => sub {
    my $categories = [ 'Pothole', 'Vegetation', 'Flytipping' ];
    my $params = {
        postcode  => 'OX20 1SZ',
        latitude  => 51.754926,
        longitude => -1.256179,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    # Create one open and one fixed report in each category
    foreach my $category ( @$categories ) {
        $mech->create_contact_ok( category => $category, body_id => $body->id, email => "$category\@example.org" );
        foreach my $state ( 'confirmed', 'fixed - user', 'fixed - council' ) {
            my %report_params = (
                %$params,
                category => $category,
                state => $state,
                external_body => "$category-$state",
            );
            $mech->create_problems_for_body( 1, $body->id, 'Around page', \%report_params );
        }
    }

    my $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
    my $pins = $json->{pins};
    is scalar @$pins, 9, 'correct number of reports when no filters';

    # Regression test for filter_category in /around URL
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok( '/around?filter_category=Pothole&bbox=' . $bbox );
        $mech->content_contains('<option value="Pothole" selected>');
    };

    $json = $mech->get_ok_json( '/around?ajax=1&filter_category=Pothole&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 3, 'correct number of Pothole reports';

    $json = $mech->get_ok_json( '/around?ajax=1&status=open&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 3, 'correct number of open reports';

    $json = $mech->get_ok_json( '/around?ajax=1&status=fixed&filter_category=Vegetation&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 2, 'correct number of fixed Vegetation reports';

    my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Default');
    $cobrand->mock('display_location_extra_params', sub { { external_body => "Pothole-confirmed" } });

    $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 1, 'correct number of external_body reports';
};

subtest 'check old problems not shown by default on around page' => sub {
    my $params = {
        postcode  => 'OX20 1SZ',
        latitude  => 51.754926,
        longitude => -1.256179,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    my $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
    my $pins = $json->{pins};
    is scalar @$pins, 9, 'correct number of reports when no age';

    my $problems = FixMyStreet::App->model('DB::Problem')->to_body( $body->id );
    $problems->first->update( { confirmed => \"current_timestamp-'7 months'::interval" } );

    $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 8, 'correct number of reports with old report';

    $json = $mech->get_ok_json( '/around?show_old_reports=1&ajax=1&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 9, 'correct number of reports with show_old_reports';

    $problems->update( { confirmed => \"current_timestamp" } );
};

subtest 'check sorting by update uses lastupdate to determine age' => sub {
    my $params = {
        postcode  => 'OX20 1SZ',
        latitude  => 51.754926,
        longitude => -1.256179,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    my $problems = FixMyStreet::App->model('DB::Problem')->to_body( $body->id );
    $problems->first->update( { confirmed => \"current_timestamp-'7 months'::interval" } );

    my $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
    my $pins = $json->{pins};
    is scalar @$pins, 8, 'correct number of reports with default sorting';


    $json = $mech->get_ok_json( '/around?ajax=1&sort=updated-desc&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 9, 'correct number of reports with updated sort';

    $problems->update( { confirmed => \"current_timestamp" } );
};

subtest 'check show old reports checkbox shown on around page' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok( '/around?pc=OX20+1SZ' );
        $mech->content_contains('id="show_old_reports_wrapper" class="report-list-filters hidden"');

        my $problems = FixMyStreet::App->model('DB::Problem')->to_body( $body->id );
        $problems->first->update( { confirmed => \"current_timestamp-'7 months'::interval" } );

        $mech->get_ok( '/around?pc=OX20+1SZ&status=all' );
        $mech->content_lacks('id="show_old_reports_wrapper" class="report-list-filters hidden"');
        $mech->content_contains('id="show_old_reports_wrapper" class="report-list-filters"');

        $problems->update( { confirmed => \"current_timestamp" } );
    };
};

subtest 'check skip_around skips around page' => sub {
    my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Default');
    $cobrand->mock('skip_around_page', sub { 1 });
    $cobrand->mock('country', sub { 1 });

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        MAPIT_TYPES => ['CTY', 'DIS'],
    }, sub {
        $mech->get('/around?latitude=51.754926&longitude=-1.256179');
        is $mech->res->previous->code, 302, "around page is a redirect";
        is $mech->uri->path, '/report/new', "and redirects to /report/new";
    };
};

subtest 'check map zoom level customisation' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
        MAP_TYPE => 'OSM',
    }, sub {
        $mech->get('/around?latitude=51.754926&longitude=-1.256179');
        $mech->content_contains('data-numZoomLevels=6');
        $mech->content_contains('data-zoomOffset=13');
    };


    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
        MAP_TYPE => 'Tester',
    }, sub {
        $mech->get('/around?latitude=51.754926&longitude=-1.256179');
        $mech->content_contains('data-numZoomLevels=99');
        $mech->content_contains('data-zoomOffset=88');
    };
};

subtest 'check nearby lookup' => sub {
    my $p = FixMyStreet::DB->resultset("Problem")->search({ external_body => "Pothole-confirmed" })->first;
    $mech->get_ok('/around/nearby?latitude=51.754926&longitude=-1.256179&filter_category=Pothole');
    $mech->content_contains('["51.754926","-1.256179","yellow",' . $p->id . ',"Around page Test 1 for ' . $body->id . '","small",false]');
};

done_testing();
