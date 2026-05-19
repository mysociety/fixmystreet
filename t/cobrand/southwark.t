use FixMyStreet::TestMech;
use Test::MockModule;
use FixMyStreet::Script::Alerts;

my $mech = FixMyStreet::TestMech->new;

# Mock tilma so TfL's report_new_is_on_tlrn method doesn't make a live API call.
use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register( $tilma->to_psgi_app, host => qr/tilma/ );

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Southwark');

$cobrand->mock('estate_feature_for_point', sub {
    my ( $self, $lat, $lon ) = @_;
    if ($lat eq "51.50352") {
        # inside an estate
        return {
                properties => {
                    Site_code => "PHAU12345"
                }
            };
    }
});


use constant SOUTHWARK_AREA_ID => 2491;

my $southwark = $mech->create_body_ok(
    SOUTHWARK_AREA_ID,
    'Southwark Council',
    { cobrand => 'southwark' },
);

my $staffuser = $mech->create_user_ok( 'staff@example.com', name => 'Staffer', from_body => $southwark );
$staffuser->user_body_permissions->create({ body => $southwark, permission_type => 'view_dashboard' });

$mech->create_contact_ok(
    body_id  => $southwark->id,
    category => 'Abandoned Bike (Street)',
    email    => 'STCL_ABBI',
);
$mech->create_contact_ok(
    body_id  => $southwark->id,
    category => 'Abandoned Bike (Estate)',
    email    => 'HOU_ABBI',
);
my $animal = $mech->create_contact_ok(
    body_id => $southwark->id,
    category => 'Clinical Waste - Dead Animal (Estates)',
    email => 'email'
);

my $tfl = $mech->create_body_ok( SOUTHWARK_AREA_ID, 'TfL' );
my $river_piers = $mech->create_contact_ok(
    body_id  => $tfl->id,
    category => 'River Piers',
    email    => 'tfl@example.org',
);
$river_piers->set_extra_metadata( group => ['River Piers'] );
$river_piers->update;
my $bus_stops = $mech->create_contact_ok(
    body_id  => $tfl->id,
    category => 'Bus Stops and Shelters',
    email    => 'tfl@example.org',
);
$bus_stops->set_extra_metadata( group => ['Bus Stops and Shelters'] );
$bus_stops->update;


FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'southwark', 'tfl' ],
    MAPIT_URL        => 'http://mapit.uk/',
}, sub {
    subtest "Correct categories shown on street" => sub {
        ok $mech->host('southwark.fixmystreet.com'), 'set host';

        my $json = $mech->get_ok_json(
            '/report/new/ajax?longitude=-0.08051&latitude=51.50351');

        is_deeply $json->{by_category} => {
            'Abandoned Bike (Street)' => {
                allow_anonymous => 'true',
                bodies => ['Southwark Council'],
            },
            'Bus Stops and Shelters' => {
                allow_anonymous => 'true',
                bodies => ['TfL'],
            },
            $animal->category => {
                allow_anonymous => 'true',
                bodies => ['Southwark Council'],
            },
        }, "Southwark 'street' area doesn't have River Piers category";

    };

    subtest "Correct categories shown on estate" => sub {
        ok $mech->host('southwark.fixmystreet.com'), 'set host';

        my $json = $mech->get_ok_json(
            '/report/new/ajax?longitude=-0.08052&latitude=51.50352');

        is_deeply $json->{by_category} => {
            'Abandoned Bike (Estate)' => {
                allow_anonymous => 'true',
                bodies => ['Southwark Council'],
            },
            $animal->category => {
                allow_anonymous => 'true',
                bodies => ['Southwark Council'],
            },
        }, "Southwark 'estate' area doesn't have TfL categories or street category";

    };

    subtest 'Photos in certain categories hidden' => sub {
        my $alert = FixMyStreet::DB->resultset('Alert')->create({
            cobrand => 'southwark',
            parameter => $southwark->id,
            alert_type => 'council_problems',
            user => $staffuser,
        });
        $alert->confirm;
        my ($p) = $mech->create_problems_for_body(1, $southwark->id, 'Title', {
            category => $animal->category,
            cobrand => 'southwark',
            areas => ',2491,',
            latitude =>  51.50351,
            longitude => -0.08051,
            photo => '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg',
            confirmed => \"current_timestamp + '3 hours'::interval",
        });
        my $url = '/report/' . $p->id;

        # No photo in alert email
        FixMyStreet::Script::Alerts::send_other();
        my $email = $mech->get_email;
        my $body;
        $email->walk_parts(sub {
            my $part = shift;
            return if $part->subparts;
            $body = $part->body_str if $part->content_type =~ m{text/html};
            unlike $part->content_type, qr/image\/jpeg/; # No photo
        });
        unlike $body, qr/<img style="float/;

        # No photo on report/around/alert pages
        $mech->get_ok($url);
        $mech->content_lacks('/photo/');
        $mech->get_ok('/around?latitude=' . $p->latitude . '&longitude=' . $p->longitude);
        $mech->content_contains($url);
        $mech->content_lacks('/photo/');
        $mech->get_ok('/alert');
        $mech->content_lacks('/photo/');

        # Staff can see it on report/around page still
        $mech->log_in_ok($staffuser->email);
        $mech->get_ok($url);
        $mech->content_contains('/photo/');
        $mech->get_ok('/around?latitude=' . $p->latitude . '&longitude=' . $p->longitude);
        $mech->content_contains($url);
        $mech->content_contains('/photo/');
        $mech->get_ok('/alert');
        $mech->content_lacks('/photo/'); # Easier just to not show them at all here
    };

    subtest 'Dashboard CSV extra columns' => sub {
        $mech->log_in_ok($staffuser->email);
        $mech->create_problems_for_body(1, $southwark->id, 'Title', {
            user => $staffuser,
            cobrand => 'southwark',
        });
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"User Email"');
        $mech->content_contains($staffuser->email);
    };
};

done_testing;
