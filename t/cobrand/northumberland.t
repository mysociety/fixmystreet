use FixMyStreet::TestMech;
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2248, 'Northumberland County Council', {}, { cobrand => 'northumberland' });
$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping', email => 'foo@northumberland', group => 'Staff Only - Out Of Hours');
$mech->create_contact_ok(body_id => $body->id, category => 'Trees', email => 'foo@northumberland');

my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body, password => 'password');
my $role = FixMyStreet::DB->resultset("Role")->create({ name => 'Role 1', body => $body, permissions => [], });
$staffuser->add_to_roles($role);

my ($problem1, $problem2) = $mech->create_problems_for_body(2, $body->id, 'Test', {
    anonymous => 't',
    extra => { contributed_by => $staffuser->id },
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'northumberland',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Dashboard CSV includes correct extra data' => sub {
        $mech->log_in_ok( $staffuser->email );
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('Test User', 'name of anonymous user');
        $mech->content_like(qr{counciluser\@example.com,"Role 1",$}, 'staff user, role, and unassigned');
        $staffuser->add_to_planned_reports($problem1);
        $staffuser->add_to_planned_reports($problem2);
        $mech->get_ok('/dashboard?export=1');
        my $id1 = $problem1->id;
        my $id2 = $problem2->id;
        $mech->content_like(qr{/report/$id1,.*?,"Role 1","Council User"}, 'staff user, role, and assigned to');
        $mech->content_like(qr{/report/$id2,.*?,"Role 1","Council User"}, 'staff user, role, and assigned to');
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
        $mech->content_contains('value=\'Flytipping\' data-nh="1"');

        # A-road where NH responsible for litter, council categories will also be present
        mock_road("A5103", 1);
        $mech->get_ok($url);
        $mech->content_contains('Litter');
        $mech->content_contains('Slip Roads');
        $mech->content_contains('Main Carriageway');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees\'>');
        $mech->content_contains('value=\'Flytipping\' data-nh="1"');

        # A-road where NH not responsible for litter, no NH litter categories
        mock_road("A34", 0);
        $mech->get_ok($url);
        $mech->content_lacks('Litter');
        $mech->content_lacks('Slip Roads');
        $mech->content_lacks('Main Carriageway');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees\'>');
        $mech->content_contains('value=\'Flytipping\' data-nh="1"');
    };
};

done_testing();
