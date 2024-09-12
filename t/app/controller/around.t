use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Map::Tester;

use Moo;
extends 'FixMyStreet::Map::FMS';
has '+zoom_levels' => ( default => 99 );
has '+min_zoom_level' => ( default => 88 );

1;

package main;

use Test::MockModule;
use t::Mock::Nominatim;

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
        errors => [
            'Error: Please enter a valid postcode or area',
            'Sorry, we could not find that location.',
        ],
        pc_alternatives => [],
    },
    {
        pc => 'Glenthorpe Ct, Katy, TX 77494, USA',
        errors => [
            'Error: Please enter a valid postcode or area',
            'Sorry, we could not find that location.',
        ],
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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

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
        $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
            "good location" );
        is_deeply $mech->page_errors, [], "no errors for pc '$test->{pc}'";
        is_deeply $mech->extract_location, $test,
          "got expected location for pc '$test->{pc}'";
        $mech->get_ok('/');
        my $pc = "$test->{latitude},$test->{longitude}";
        $mech->submit_form_ok( { with_fields => { pc => $pc } },
            "good location" );
        is_deeply $mech->page_errors, [], "no errors for pc '$pc'";
        is_deeply $mech->extract_location, { %$test, pc => $pc },
          "got expected location for pc '$pc'";
    };
}

subtest "check lat/lng for full plus code" => sub {
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "9C7RXR26+R5" } } );
    is_deeply $mech->page_errors, [], "no errors for plus code";
    is_deeply $mech->extract_location, {
        pc => "9C7RXR26+R5",
        latitude  => 55.952063,
        longitude => -3.189562,
    },
      "got expected location for full plus code";
};

subtest "check lat/lng for short plus code" => sub {
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "XR26+R5 Edinburgh" } } );
    is_deeply $mech->page_errors, [], "no errors for plus code";
    is_deeply $mech->extract_location, {
        pc => "XR26+R5 Edinburgh",
        latitude  => 55.952063,
        longitude => -3.189562,
    },
      "got expected location for short plus code";
};

subtest 'check lat/lng for Maidenhead code' => sub {
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "IO92NB83" } } );
    is_deeply $mech->page_errors, [], "no errors for code";
    is_deeply $mech->extract_location, {
        pc => "IO92NB83",
        latitude  => 52.0560763888889,
        longitude => -0.846180555555549,
    },
      "got expected location for Maidenhead code";
};

my $body_edin = $mech->create_body_ok(2651, 'City of Edinburgh Council');
my $body_edin_id = $body_edin->id;
my $body_west = $mech->create_body_ok(2504, 'Westminster City Council', {}, { cobrand => 'westminster' });

my @edinburgh_problems = $mech->create_problems_for_body( 5, $body_edin_id, 'Around page', {
    postcode  => 'EH1 1BB',
    latitude  => 55.9519637512,
    longitude => -3.17492254484,
});

subtest 'check lookup by reference' => sub {
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => '12345' } }, 'bad ref');
    $mech->content_contains('Searching found no reports');
    my $id = $edinburgh_problems[0]->id;
    $mech->submit_form_ok( { with_fields => { pc => $id } }, 'good ref');
    is $mech->uri->path, "/report/$id", "redirected to report page";
};

subtest 'check lookup by reference does not show non_public reports' => sub {
    $edinburgh_problems[0]->update({
        non_public => 1
    });
    my $id = $edinburgh_problems[0]->id;
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => $id } }, 'non_public ref');
    $mech->content_contains('Searching found no reports');
};

subtest '...unless staff' => sub {
    my $user = $mech->log_in_ok( 'test@example.com' );
    $user->update({ from_body => $body_edin });
    $user->user_body_permissions->find_or_create({ body => $body_edin, permission_type => 'report_mark_private' });
    my $id = $edinburgh_problems[0]->id;
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => $id } }, 'non_public ref');
    is $mech->uri->path, "/report/$id", "redirects to correct report";
    $mech->log_out_ok;
};

subtest 'check non public reports are not displayed on around page' => sub {
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
        "good location" );
    $mech->content_contains( "Around page Test 3 for $body_edin_id",
        'problem to be marked non public visible' );

    my $private = $edinburgh_problems[2];
    ok $private->update( { non_public => 1 } ), 'problem marked non public';

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
        "good location" );
    $mech->content_lacks( "Around page Test 3 for $body_edin_id",
        'problem marked non public is not visible' );
};

subtest 'check missing body message not shown when it does not need to be' => sub {
    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
        "good location" );
    $mech->content_lacks('yet have details for the other councils that cover this location');
};

for my $permission ( qw/ report_inspect report_mark_private/ ) {
    subtest "check non public reports are displayed on around page with $permission permission" => sub {
        my $user = $mech->log_in_ok( 'test@example.com' );
        $user->user_body_permissions->delete();
        $user->update({ from_body => $body_edin });
        $user->user_body_permissions->find_or_create({
            body => $body_edin,
            permission_type => $permission,
        });

        $mech->get_ok('/');
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
            "good location" );
        $mech->content_contains( "Around page Test 3 for $body_edin_id",
            'problem marked non public is visible' );
        $mech->content_contains( "Around page Test 2 for $body_edin_id",
            'problem marked public is visible' );

        $mech->get_ok('/around?pc=EH1+1BB&status=non_public');
        $mech->content_contains( "Around page Test 3 for $body_edin_id",
            'problem marked non public is visible' );
        $mech->content_lacks( "Around page Test 2 for $body_edin_id",
            'problem marked public is not visible' );

        $user->user_body_permissions->delete();
        $user->update({ from_body => $body_west });
        $user->user_body_permissions->find_or_create({
            body => $body_west,
            permission_type => $permission,
        });

        $mech->get_ok('/');
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
            "good location" );
        $mech->content_lacks( "Around page Test 3 for $body_edin_id",
            'problem marked non public is not visible' );
        $mech->content_contains( "Around page Test 2 for $body_edin_id",
            'problem marked public is visible' );

        $mech->get_ok('/around?pc=EH1+1BB&status=non_public');
        $mech->content_lacks( "Around page Test 3 for $body_edin_id",
            'problem marked non public is not visible' );
        $mech->content_lacks( "Around page Test 2 for $body_edin_id",
            'problem marked public is visible' );
    };
}

subtest 'check assigned-only list items do not display shortlist buttons' => sub {
    my $contact = $mech->create_contact_ok( category => 'Horses & Ponies', body_id => $body_edin->id, email => "horses\@example.org" );
    $edinburgh_problems[4]->update({ category => 'Horses & Ponies' });

    my $user = $mech->log_in_ok( 'test@example.com' );
    $user->set_extra_metadata(assigned_categories_only => 1);
    $user->user_body_permissions->delete();
    $user->set_extra_metadata(categories => [ $contact->id ]);
    $user->update({ from_body => $body_edin });
    $user->user_body_permissions->find_or_create({ body => $body_edin, permission_type => 'planned_reports' });

    $mech->get_ok('/around?pc=EH1+1BB');
    $mech->content_contains('shortlist-add-' . $edinburgh_problems[4]->id);
    $mech->content_lacks('shortlist-add-' . $edinburgh_problems[3]->id);
    $mech->content_lacks('shortlist-add-' . $edinburgh_problems[1]->id);
};

}; # End big override_config

my $body = $mech->create_body_ok(2237, "Oxfordshire", {}, { cobrand => 'oxfordshire' });

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
        my $contact = $mech->create_contact_ok( category => $category, body_id => $body->id, email => "$category\@example.org" );
        if ($category eq 'Vegetation') {
            $contact->set_extra_metadata(group => ['Environment', 'Green']);
            $contact->update;
        } elsif ($category eq 'Flytipping') {
            $contact->set_extra_metadata(group => ['Environment']);
            $contact->update;
        }
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
        COBRAND_FEATURES => { category_groups => { fixmystreet => 1 } },
    }, sub {
        $mech->get_ok( '/around?filter_category=Pothole&bbox=' . $bbox );
        $mech->content_contains('<option value="Pothole" selected>');
        $mech->content_contains('<optgroup label="Environment">');

        $mech->get_ok( '/around?filter_group=Environment&bbox=' . $bbox );
        $mech->content_contains('<option value="Flytipping" selected>');

        $mech->get_ok( '/around?filter_group=Environment&filter_category=Vegetation&bbox=' . $bbox );
        $mech->content_like(qr/<optgroup label="Environment">.*?<option value="Vegetation" selected>.*?<optgroup label="Green">.*?<option value="Vegetation">/s);
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

my $district = $mech->create_body_ok(2421, "Oxford City");

subtest 'check categories with same name are only shown once in filters' => sub {
    my $params = {
        postcode  => 'OX20 1SZ',
        latitude  => 51.754926,
        longitude => -1.256179,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    # Identically-named categories should be combined even if their extra metadata is different
    my $contact2 = $mech->create_contact_ok( category => "Pothole", body_id => $district->id, email => 'pothole@district-example.org' );
    $contact2->set_extra_metadata(some_extra_field => "dummy");
    $contact2->update;
    # And categories with the same display name should be combined too
    my $contact3 = $mech->create_contact_ok( category => "Pothole (alternative)", body_id => $district->id, email => 'pothole-alternative@district-example.org' );
    $contact3->set_extra_metadata(display_name => "Pothole");
    $contact3->update;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => { category_groups => { fixmystreet => 1 } },
    }, sub {
        $mech->get_ok( '/around?bbox=' . $bbox );
        $mech->content_contains('<option value="Pothole">');
        $mech->content_unlike(qr{Pothole</option>.*<option value="Pothole">\s*Pothole</option>}s, "Pothole category only appears once");
        $mech->content_lacks('<option value="Pothole (alternative)">');
    };
};

subtest 'check staff categories shown appropriately in filter' => sub {
    my $params = {
        postcode  => 'OX20 1SZ',
        latitude  => 51.754926,
        longitude => -1.256179,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    $mech->create_contact_ok( category => "Needles district", body_id => $district->id, email => 'needles@district.example.org', state => 'staff' );
    $mech->create_contact_ok( category => "Needles county", body_id => $body->id, email => 'needles@county.example.org', state => 'staff' );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => { category_groups => { fixmystreet => 1 } },
    }, sub {
        $mech->get_ok( '/around?bbox=' . $bbox );
        $mech->content_lacks('<option value="Needles district">');
        $mech->content_lacks('<option value="Needles county">');
        my $user = $mech->log_in_ok( 'test@example.com' );
        $user->update({ from_body => $district });
        $user->user_body_permissions->find_or_create({ body => $district, permission_type => 'report_mark_private' });
        $mech->get_ok( '/around?bbox=' . $bbox );
        $mech->content_contains('<option value="Needles district">');
        $mech->content_lacks('<option value="Needles county">');
        $mech->log_out_ok;
    };
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

    my $problems = FixMyStreet::DB->resultset('Problem')->to_body( $body->id );
    $problems->first->update( { confirmed => \"current_timestamp-'7 months'::interval" } );

    $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 8, 'correct number of reports with old report';

    $json = $mech->get_ok_json( '/around?show_old_reports=1&ajax=1&bbox=' . $bbox );
    $pins = $json->{pins};
    is scalar @$pins, 9, 'correct number of reports with show_old_reports';

    $problems->update( { confirmed => \"current_timestamp" } );
};

subtest 'check sorting' => sub {
    my $params = {
        postcode  => 'OX20 1SZ',
        latitude  => 51.754926,
        longitude => -1.256179,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    subtest 'by update uses lastupdate to determine age' => sub {
        my $problems = FixMyStreet::DB->resultset('Problem')->to_body( $body->id );
        $problems->first->update( { confirmed => \"current_timestamp-'7 months'::interval" } );

        my $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 8, 'correct number of reports with default sorting';

        $json = $mech->get_ok_json( '/around?ajax=1&sort=updated-desc&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 9, 'correct number of reports with updated sort';

        $problems->update( { confirmed => \"current_timestamp" } );
    };

    subtest 'by comment count' => sub {
        my @problems = FixMyStreet::DB->resultset('Problem')->to_body( $body->id )->all;
        $mech->create_comment_for_problem($problems[3], $problems[0]->user, 'Name', 'Text', 'f', 'confirmed', 'confirmed');
        $mech->create_comment_for_problem($problems[3], $problems[0]->user, 'Name', 'Text', 'f', 'confirmed', 'confirmed');
        $mech->create_comment_for_problem($problems[6], $problems[0]->user, 'Name', 'Text', 'f', 'confirmed', 'confirmed');
        my $json = $mech->get_ok_json( '/around?ajax=1&sort=comments-desc&bbox=' . $bbox );
        my $pins = $json->{pins};
        is $pins->[0][3], $problems[3]->id, 'Report with two updates first';
        is $pins->[1][3], $problems[6]->id, 'Report with one update second';
    };
};

subtest 'check show old reports checkbox shown on around page' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok( '/around?pc=OX20+1SZ' );
        $mech->content_like(qr/id="show_old_reports_wrapper"[^>]*report-list-filters hidden"/);

        my $problems = FixMyStreet::DB->resultset('Problem')->to_body( $body->id );
        $problems->first->update( { confirmed => \"current_timestamp-'7 months'::interval" } );

        $mech->get_ok( '/around?pc=OX20+1SZ&status=all' );
        $mech->content_unlike(qr/id="show_old_reports_wrapper"[^>]*report-list-filters hidden"/);
        $mech->content_like(qr/id="show_old_reports_wrapper"[^>]*report-list-filters"/);

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
        $mech->content_contains('data-numZoomLevels=7');
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

subtest 'check nearby lookup, default behaviour' => sub {
    my $p = FixMyStreet::DB->resultset("Problem")->search({ external_body => "Pothole-confirmed" })->first;
    $mech->get_ok('/around/nearby?latitude=51.754926&longitude=-1.256179&filter_category=Pothole');
    $mech->content_contains('[51.754926,-1.256179,"yellow",' . $p->id . ',"Around page Test 1 for ' . $body->id . '","small",false]');
};

my $oxfordshire_cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Oxfordshire');
$oxfordshire_cobrand->mock('defect_wfs_query', sub { return { features => [] }; });

subtest 'check nearby lookup, cobrand custom distances' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            nearby_distances => { oxfordshire => {
                inspector => 500,
                suggestions => 100,
            } },
        }
    }, sub {

        $mech->delete_problems_for_body($body->id);
        my ($p) = $mech->create_problems_for_body( 1, $body->id, 'Around page', {
            postcode  => 'OX20 1SZ',
            latitude  => 51.754926,
            longitude => -1.256179,
            category => "Pothole",
        });
        for my $test (
            { lat => 51.7549, lon => -1.256, mode => undef, contains => 1}, # 12m away
            { lat => 51.752, lon => -1.256, mode => undef, contains => 1}, # 325m away
            { lat => 51.7485, lon => -1.256, mode => undef, contains => 1}, # 714m away
            { lat => 51.74, lon => -1.256, mode => undef, contains => 0}, # 1660m away

            { lat => 51.7549, lon => -1.256, mode => 'inspector', contains => 1}, # 12m away
            { lat => 51.752, lon => -1.256, mode => 'inspector', contains => 1}, # 325m away
            { lat => 51.7485, lon => -1.256, mode => 'inspector', contains => 0}, # 714m away
            { lat => 51.74, lon => -1.256, mode => 'inspector', contains => 0}, # 1660m away

            { lat => 51.7549, lon => -1.256, mode => 'suggestions', contains => 1}, # 12m away
            { lat => 51.752, lon => -1.256, mode => 'suggestions', contains => 0}, # 325m away
            { lat => 51.7485, lon => -1.256, mode => 'suggestions', contains => 0}, # 714m away
            { lat => 51.74, lon => -1.256, mode => 'suggestions', contains => 0}, # 1660m away
        ) {
            $mech->get_ok( '/around/nearby?latitude=' . $test->{lat}
                    . '&longitude=' . $test->{lon}
                    . '&filter_category=Pothole'
                    . ( $test->{mode} ? '&mode=' . $test->{mode} : '' )
            );
            $mech->contains_or_lacks($test->{contains}, '[51.754926,-1.256179,"yellow",' . $p->id . ',"Open: Around page Test 1 for ' . $body->id . '","small",false]');
        }
    };
};

subtest 'check nearby lookup, cobrand custom distances per category' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            nearby_distances => {
                oxfordshire => {
                    suggestions => {
                        _fallback => 800,
                        'Subcat 1 in Group 1' => 100,
                        'Group 1' => 400,
                        'No suggestions category' => 0,
                    },
                },
            },
        }
    }, sub {
        $mech->delete_problems_for_body($body->id);

        my ($p_1_g_1) = $mech->create_problems_for_body( 1, $body->id, 'Around page', {
            postcode  => 'OX20 1SZ',
            latitude  => 51.754926,
            longitude => -1.256179,
            category => 'Subcat 1 in Group 1',
        });
        my ($p_2_g_1) = $mech->create_problems_for_body( 1, $body->id, 'Around page', {
            postcode  => 'OX20 1SZ',
            latitude  => 51.754926,
            longitude => -1.256179,
            category => 'Subcat 2 in Group 1',
        });
        my ($p_g_2) = $mech->create_problems_for_body( 1, $body->id, 'Around page', {
            postcode  => 'OX20 1SZ',
            latitude  => 51.754926,
            longitude => -1.256179,
            category => 'Subcat in Group 2',
        });
        $mech->create_problems_for_body( 1, $body->id, 'Around page', {
            postcode  => 'OX20 1SZ',
            latitude  => 51.754926,
            longitude => -1.256179,
            category => 'No suggestions category',
        });

        note 'filter_category = Subcat 1 in Group 1, filter_group = Group 1';
        for my $test (
            { lat => 51.7549, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat 1 in Group 1', filter_group => 'Group 1', contains => 1}, # 12m away
            { lat => 51.752, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat 1 in Group 1', filter_group => 'Group 1', contains => 0}, # 325m away
            { lat => 51.7485, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat 1 in Group 1', filter_group => 'Group 1', contains => 0}, # 714m away
            { lat => 51.74, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat 1 in Group 1', filter_group => 'Group 1', contains => 0}, # 1660m away
        ) {
            $mech->get_ok( '/around/nearby?latitude=' . $test->{lat}
                    . '&longitude=' . $test->{lon}
                    . '&mode=' . $test->{mode}
                    . '&filter_category=' . $test->{filter_category}
                    . '&filter_group=' . $test->{filter_group} );
            for my $test_p (
                { id => $p_1_g_1->id, captured_by_category_filters => 1 },
                { id => $p_2_g_1->id, captured_by_category_filters => 0 },
                { id => $p_g_2->id,   captured_by_category_filters => 0 },
            ) {
                note '    Check for problem ' . $test_p->{id};
                $mech->contains_or_lacks(
                    $test->{contains} && $test_p->{captured_by_category_filters},
                    '[51.754926,-1.256179,"yellow",'
                        . $test_p->{id}
                        . ',"Open: Around page Test 1 for '
                        . $body->id
                        . '","small",false]'
                );
            }
        }

        # There is no config for 'Subcat 2 in Group 1' so it should fall back
        # to the config for 'Group 1'
        note 'filter_category = Subcat 2 in Group 1, filter_group = Group 1';
        for my $test (
            { lat => 51.7549, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat 2 in Group 1', filter_group => 'Group 1', contains => 1}, # 12m away
            { lat => 51.752, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat 2 in Group 1', filter_group => 'Group 1', contains => 1}, # 325m away
            { lat => 51.7485, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat 2 in Group 1', filter_group => 'Group 1', contains => 0}, # 714m away
            { lat => 51.74, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat 2 in Group 1', filter_group => 'Group 1', contains => 0}, # 1660m away
        ) {
            $mech->get_ok( '/around/nearby?latitude=' . $test->{lat}
                    . '&longitude=' . $test->{lon}
                    . '&mode=' . $test->{mode}
                    . '&filter_category=' . $test->{filter_category}
                    . '&filter_group=' . $test->{filter_group} );
            for my $test_p (
                { id => $p_1_g_1->id, captured_by_category_filters => 0 },
                { id => $p_2_g_1->id, captured_by_category_filters => 1 },
                { id => $p_g_2->id,   captured_by_category_filters => 0 },
            ) {
                note '    Check for problem ' . $test_p->{id};
                $mech->contains_or_lacks(
                    $test->{contains} && $test_p->{captured_by_category_filters},
                    '[51.754926,-1.256179,"yellow",'
                        . $test_p->{id}
                        . ',"Open: Around page Test 1 for '
                        . $body->id
                        . '","small",false]'
                );
            }
        }

        # There is no config for 'Subcat in Group 2' or 'Group 2', so should
        # fall back to the default for the cobrand
        note 'filter_category = Subcat in Group 2, filter_group = Group 2';
        for my $test (
            { lat => 51.7549, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat in Group 2', filter_group => 'Group 2', contains => 1}, # 12m away
            { lat => 51.752, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat in Group 2', filter_group => 'Group 2', contains => 1}, # 325m away
            { lat => 51.7485, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat in Group 2', filter_group => 'Group 2', contains => 1}, # 714m away
            { lat => 51.74, lon => -1.256, mode => 'suggestions', filter_category => 'Subcat in Group 2', filter_group => 'Group 2', contains => 0}, # 1660m away
        ) {
            $mech->get_ok( '/around/nearby?latitude=' . $test->{lat}
                    . '&longitude=' . $test->{lon}
                    . '&mode=' . $test->{mode}
                    . '&filter_category=' . $test->{filter_category}
                    . '&filter_group=' . $test->{filter_group} );
            for my $test_p (
                { id => $p_1_g_1->id, captured_by_category_filters => 0 },
                { id => $p_2_g_1->id, captured_by_category_filters => 0 },
                { id => $p_g_2->id,   captured_by_category_filters => 1 },
            ) {
                note 'Check for problem ' . $test_p->{id};
                $mech->contains_or_lacks(
                    $test->{contains} && $test_p->{captured_by_category_filters},
                    '[51.754926,-1.256179,"yellow",'
                        . $test_p->{id}
                        . ',"Open: Around page Test 1 for '
                        . $body->id
                        . '","small",false]'
                );
            }
        }

        note 'filter_category = No suggestions category';
        for my $test (
            { lat => 51.754926, lon => -1.256179 }, # 0m away
            { lat => 51.7549, lon => -1.256 }, # 12m away
            { lat => 51.752, lon => -1.256 }, # 325m away
            { lat => 51.7485, lon => -1.256 }, # 714m away
            { lat => 51.74, lon => -1.256 }, # 1660m away
        ) {
            my $json = $mech->get_ok_json( '/around/nearby?latitude=' . $test->{lat}
                    . '&longitude=' . $test->{lon}
                    . '&mode=suggestions'
                    . '&filter_category=No suggestions category' );
            is_deeply $json, { pins => [] }, 'No suggestions category should not be shown';
        }
    };
};

my $he = Test::MockModule->new('HighwaysEngland');
$he->mock('_lookup_db', sub {
    my ($road, $table, $thing, $thing_name) = @_;

    if ($road eq 'M6' && $thing eq '11') {
        return { latitude => 52.65866, longitude => -2.06447 };
    } elsif ($road eq 'M5' && $thing eq '132.5') {
        return { latitude => 51.5457, longitude => 2.57136 };
    }
});

subtest 'junction lookup' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk',
        MAPIT_TYPES => ['EUR'],
    }, sub {
        $mech->log_out_ok;

        $mech->get_ok('/');
        $mech->submit_form_ok({ with_fields => { pc => 'M6, Junction 11' } });
        $mech->content_contains('52.65866');

        $mech->get_ok('/');
        $mech->submit_form_ok({ with_fields => { pc => 'M5 132.5' } });
        $mech->content_contains('51.5457');
    };
};

done_testing();
