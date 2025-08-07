use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Map::OS::Leisure;
use FixMyStreet::Script::CSVExport;
use Test::MockModule;
use File::Temp 'tempdir';

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2248, 'Northumberland County Council', { cobrand => 'northumberland' });
$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping', email => 'foo@northumberland', group => 'Staff Only - Out Of Hours');
$mech->create_contact_ok(body_id => $body->id, category => 'Trees', email => 'foo@northumberland');

my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body, password => 'password');
my $role = FixMyStreet::DB->resultset("Role")->create({ name => 'Role 1', body => $body, permissions => [], });
$staffuser->add_to_roles($role);

my ($problem1, $problem2) = $mech->create_problems_for_body(2, $body->id, 'Test', {
    anonymous => 't',
    extra => { contributed_by => $staffuser->id },
});
$problem2->update({ state => 'fixed - council' });
my ($update) = $mech->create_comment_for_problem(
    $problem2, $staffuser, 'Title', 'text', 0, 'confirmed', 'fixed',
    { confirmed => $problem2->confirmed->add(days => 1, hours => 3, minutes => 37) }
);
$update->update({ problem_state => '' }); # simulate a questionnaire response which has mark_fixed true and no problem_state

# Have it so problem1 only has hidden updates
$mech->create_comment_for_problem($problem1, $staffuser, 'Title', 'text', 0, 'hidden', '');

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'northumberland',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
}, sub {
    subtest 'Dashboard CSV includes correct extra data' => sub {
        $mech->log_in_ok( $staffuser->email );
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('Test User', 'name of anonymous user');
        $mech->content_like(qr{counciluser\@example.com,"Role 1",,"1 day, 3 hours, 37 minutes",$}, 'staff user, role, unassigned, and response time');
        $staffuser->add_to_planned_reports($problem1);
        $staffuser->add_to_planned_reports($problem2);
        $mech->get_ok('/dashboard?export=1');
        my $id1 = $problem1->id;
        my $id2 = $problem2->id;
        $mech->content_like(qr{/report/$id1,.*?,"Role 1","Council User"}, 'staff user, role, and assigned to');
        $mech->content_like(qr{/report/$id2,.*?,"Role 1","Council User","1 day, 3 hours, 37 minutes"}, 'staff user, role, assigned to, and response time');

        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('Test User', 'name of anonymous user');
        $mech->content_like(qr{/report/$id1,.*?,"Role 1","Council User"}, 'staff user, role, and assigned to');
        $mech->content_like(qr{/report/$id2,.*?,"Role 1","Council User","1 day, 3 hours, 37 minutes"}, 'staff user, role, assigned to, and response time');
    };

    subtest 'Staff OOH shown on National Highways roads' => sub {
        my $he = $mech->create_body_ok(2248, 'National Highways');
        $mech->create_contact_ok(body_id => $he->id, category => 'Slip Roads (NH)', email => 'litter@he', group => 'Litter');
        $mech->create_contact_ok(body_id => $he->id, category => 'Main Carriageway (NH)', email => 'litter@he', group => 'Litter');
        $mech->create_contact_ok(body_id => $he->id, category => 'Potholes (NH)', email => 'potholes@he');

        our $he_mod = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
        sub mock_road {
            my ($name, $litter) = @_;
            $he_mod->mock('_fetch_features', sub {
                my ($self, $cfg, $x, $y) = @_;
                my $road = {
                    properties => { area_name => 'Area 1', ROA_NUMBER => $name, sect_label => "$name/111" },
                    geometry => {
                        type => 'LineString',
                        coordinates => [ [ $x-2, $y+2 ], [ $x+2, $y+2 ] ],
                    }
                };
                if ($cfg->{typename} eq 'highways_litter_pick') {
                    return $litter ? [$road] : [];
                }
                return [$road];
            });
        }

        my $url = "/report/new?longitude=-1.691012&latitude=55.169081";
        # Motorway, NH responsible for litter (but not in dataset), council categories will also be present
        mock_road("M1", 0);
        $mech->get_ok($url);
        $mech->content_contains('Litter');
        $mech->content_contains('Slip Roads');
        $mech->content_contains('Main Carriageway');
        $mech->content_contains('Potholes');
        $mech->content_contains("Trees'>");
        $mech->content_contains('value=\'H|Staff Only - Out Of Hours|Flytipping\' data-nh="1"');

        # A-road where NH responsible for litter, council categories will also be present
        mock_road("A5103", 1);
        $mech->get_ok($url);
        $mech->content_contains('Litter');
        $mech->content_contains('Slip Roads');
        $mech->content_contains('Main Carriageway');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees\'>');
        $mech->content_contains('value=\'H|Staff Only - Out Of Hours|Flytipping\' data-nh="1"');

        # A-road where NH not responsible for litter, no NH litter categories
        mock_road("A34", 0);
        $mech->get_ok($url);
        $mech->content_lacks('Litter');
        $mech->content_lacks('Slip Roads');
        $mech->content_lacks('Main Carriageway');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees\'>');
        $mech->content_contains('value=\'H|Staff Only - Out Of Hours|Flytipping\' data-nh="1"');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'northumberland', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        os_maps_leisure => { _fallback => 1 }
    }
}, sub {
    my $o = Open311->new( fixmystreet_body => $body );

    my $superuser = $mech->create_user_ok(
        'superuser@example.com',
        name         => 'Super User',
        is_superuser => 1,
    );
    $mech->log_in_ok( $superuser->email );

    for my $host ( 'northumberland', 'fixmystreet' ) {
        ok $mech->host($host), "change host to $host";

        my ($problem_to_update) = $mech->create_problems_for_body(
            1,
            $body->id,
            'Test',
            { cobrand => $host, external_id => 123 },
        );

        subtest "User assignment on $host site" => sub {
            $mech->get_ok( '/report/' . $problem_to_update->id );
            $mech->submit_form_ok({ form_id => 'planned_form' });
            my $comment
                = $problem_to_update->comments->order_by('-id')->first;
            is_deeply $comment->get_extra_metadata, {
                shortlisted_user => $superuser->email,
                is_superuser     => 1,
            }, 'Comment created for user assignment';

            my $id = $o->post_service_request_update($comment);
            my $cgi = CGI::Simple->new($o->test_req_used->content);
            is $cgi->param('attribute[assigned_to_user_email]'),
                $superuser->email,
                'correct assigned_to_user_email attribute';
            is $cgi->param('attribute[extra_details]'),
                '',
                'correct extra_details attribute';

            $mech->get_ok( '/report/' . $problem_to_update->id );
            $mech->submit_form_ok({ form_id => 'planned_form' });
            $comment
                = $problem_to_update->comments->order_by('-id')->first;
            is_deeply $comment->get_extra_metadata, {
                shortlisted_user => undef,
                is_superuser     => 1,
            }, 'Comment created for user un-assignment';

            $id = $o->post_service_request_update($comment);
            $cgi = CGI::Simple->new($o->test_req_used->content);
            is $cgi->param('attribute[assigned_to_user_email]'),
                '',
                'correct assigned_to_user_email attribute';
            is $cgi->param('attribute[extra_details]'),
                '',
                'correct extra_details attribute';
        };

        subtest "Extra details on $host site" => sub {
            $mech->get_ok( '/report/' . $problem_to_update->id );
            $mech->submit_form(
                button  => 'save',
                with_fields => {
                    detailed_information => 'ABC',
                    include_update       => 0,
                },
            );
            my $comment
                = $problem_to_update->comments->order_by('-id')->first;
            is_deeply $comment->get_extra_metadata, {
                detailed_information => 1,
                is_superuser         => 1,
            }, 'Comment created for extra details';

            my $id = $o->post_service_request_update($comment);
            my $cgi = CGI::Simple->new($o->test_req_used->content);
            is $cgi->param('attribute[assigned_to_user_email]'),
                '',
                'correct assigned_to_user_email attribute';
            is $cgi->param('attribute[extra_details]'),
                'ABC',
                'correct extra_details attribute';

            $mech->get_ok( '/report/' . $problem_to_update->id );
            $mech->submit_form(
                button  => 'save',
                with_fields => {
                    detailed_information => '',
                    include_update       => 0,
                },
            );
            $comment
                = $problem_to_update->comments->order_by('-id')->first;
            is_deeply $comment->get_extra_metadata, {
                detailed_information => 1,
                is_superuser         => 1,
            }, 'Comment created for extra details unsetting';
            is_deeply $problem_to_update->get_extra_metadata,
                {},
                'Extra details unset on problem';

            $id = $o->post_service_request_update($comment);
            $cgi = CGI::Simple->new($o->test_req_used->content);
            is $cgi->param('attribute[assigned_to_user_email]'),
                '',
                'correct assigned_to_user_email attribute';
            is $cgi->param('attribute[extra_details]'),
                '',
                'correct extra_details attribute';
        };
    }

    subtest 'Correct mapping' => sub {
        my $map = FixMyStreet::Map::OS::Leisure->new( cobrand => $body->get_cobrand_handler );
        for my $aerial (0, 1) {
            for my $zoom (3..11) {
                my $tiles = $map->map_tiles(
                    x_tile => 32421, y_tile => 21505, zoom_act => $zoom, aerial => $aerial,
                );
                my $layer = $aerial ? 'northumberlandaerial@osmaps' :
                    $zoom >= 10 ? 'oml@osmaps' :
                    $zoom == 7 || $zoom == 8 ? 'Leisure_27700' :
                    'Road_27700';
                like $tiles->[0], qr/$layer\/$zoom/, "with zoom $zoom and aerial $aerial";
            }
        }
    };
};

done_testing();
