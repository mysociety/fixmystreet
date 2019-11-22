use FixMyStreet::TestMech;
# avoid wide character warnings from the category change message
use open ':std', ':encoding(UTF-8)';

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $user2 = $mech->create_user_ok('test2@example.com', name => 'Test User 2');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $oxfordshirecontact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

my $oxford = $mech->create_body_ok(2421, 'Oxford City Council');
$mech->create_contact_ok( body_id => $oxford->id, category => 'Graffiti', email => 'graffiti@example.net' );

my $bromley = $mech->create_body_ok(2482, 'Bromley Council');

my $user3 = FixMyStreet::DB->resultset('User')->create( { email => 'test3@example.com' } );

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::DB->resultset('Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        bodies_str         => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Report to Edit',
        detail             => 'Detail for Report to Edit',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        external_id        => '13',
        state              => 'confirmed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => '',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
        whensent           => $dt->ymd . ' ' . $dt->hms,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

$mech->log_in_ok( $superuser->email );

subtest 'show flagged entries' => sub {
    $report->flagged( 1 );
    $report->update;
    $mech->get_ok('/admin/flagged');
    $mech->content_contains( $report->title );
};

my $update = FixMyStreet::DB->resultset('Comment')->create(
    {
        text => 'this is an update',
        user => $user,
        state => 'confirmed',
        problem => $report,
        mark_fixed => 0,
        anonymous => 1,
    }
);

subtest 'report search' => sub {
    $mech->get_ok('/admin/reports');
    $mech->get_ok('/admin/reports?search=' . $report->id );

    $mech->content_contains( $report->title );
    my $r_id = $report->id;
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );

    $mech->get_ok('/admin/reports?search=' . $report->external_id);
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );

    $mech->get_ok('/admin/reports?search=ref:' . $report->external_id);
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );

    $mech->get_ok('/admin/reports?search=' . $report->user->email);

    my $u_id = $update->id;
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id#update_$u_id"[^>]*>$u_id</a>} );

    $update->state('hidden');
    $update->update;

    $mech->get_ok('/admin/reports?search=' . $report->user->email);
    $mech->content_like( qr{<tr [^>]*hidden[^>]*> \s* <td[^>]*> \s* $u_id \s* </td>}xs );

    $report->state('hidden');
    $report->update;

    $mech->get_ok('/admin/reports?search=' . $report->user->email);
    $mech->content_like( qr{<tr [^>]*hidden[^>]*> \s* <td[^>]*> \s* $r_id \s* </td>}xs );

    $report->state('fixed - user');
    $report->update;

    $mech->get_ok('/admin/reports?search=' . $report->user->email);
    $mech->content_like( qr{href="http://[^/]*[^.]/report/$r_id"[^>]*>$r_id</a>} );
};

done_testing();
