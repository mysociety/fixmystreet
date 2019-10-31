use Test::MockModule;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::BathNES');
$cobrand->mock('area_types', sub { [ 'UTA' ] });

my $body = $mech->create_body_ok(2551, 'Bath and North East Somerset Council');
my @cats = ('Litter', 'Other', 'Potholes', 'Traffic lights');
for my $contact ( @cats ) {
    $mech->create_contact_ok(body_id => $body->id, category => $contact, email => "$contact\@example.org");
}
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
my $normaluser = $mech->create_user_ok('normaluser@example.com', name => 'Normal User');
$normaluser->update({ phone => "+447123456789" });

my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Potholes', cobrand => 'fixmystreet',
    user => $normaluser, service => 'iOS', extra => {
        _fields => [
            {
                description => 'Width of pothole?',
                name => "width",
                value => "10cm"
            },
            {
                description => 'Depth of pothole?',
                name => "depth",
                value => "25cm"
            },
        ]
    }
});
$mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Traffic lights', cobrand => 'bathnes',
    user => $counciluser, extra => {
        contributed_as => 'body',
    }
});
$mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Litter', cobrand => 'bathnes',
    user => $normaluser, extra => {
        contributed_as => 'another_user',
        contributed_by => $counciluser->id,
    }
});
$mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Other', cobrand => 'bathnes',
    user => $counciluser, extra => {
        contributed_as => 'anonymous_user',
    }
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bathnes' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

subtest 'cobrand displays council name' => sub {
    ok $mech->host("bathnes.fixmystreet.com"), "change host to bathnes";
    $mech->get_ok('/');
    $mech->content_like( qr/Bath and North East Somerset\b/ );
};

subtest 'check override contact display name' => sub {
    $mech->log_in_ok( $superuser->email );
    $mech->get_ok("/admin/body/" . $body->id . '/Litter');
    $mech->content_contains('<h1>Litter</h1>');
    $mech->content_contains('extra[display_name]');
    $mech->submit_form_ok({ with_fields => {
        'extra[display_name]' => 'Wittering'
    }});
    $mech->get_ok('/reports/Bath+and+North+East+Somerset');
    $mech->content_like(qr/Traffic lights<\/option>\s*<option value="Litter">\s*Wittering<\/option>/);
    $mech->content_lacks('Litter</option>');
};

subtest 'extra CSV columns are absent if permission not granted' => sub {
    $mech->log_in_ok( $counciluser->email );

    $mech->get_ok('/dashboard?export=1');

    my @rows = $mech->content_as_csv;
    is scalar @rows, 5, '1 (header) + 4 (reports) = 5 lines';

    is scalar @{$rows[0]}, 20, '20 columns present';

    is_deeply $rows[0],
        [
            'Report ID',
            'Title',
            'Detail',
            'User Name',
            'Category',
            'Created',
            'Confirmed',
            'Acknowledged',
            'Fixed',
            'Closed',
            'Status',
            'Latitude',
            'Longitude',
            'Query',
            'Ward',
            'Easting',
            'Northing',
            'Report URL',
            'Site Used',
            'Reported As',
        ],
        'Column headers look correct';
};

subtest "Custom CSV fields permission can be granted" => sub {
    $mech->log_in_ok( $superuser->email );

    is $counciluser->user_body_permissions->count, 0, 'counciluser has no permissions';

    $mech->get_ok("/admin/users/" . $counciluser->id);
    $mech->content_contains('Extra columns in CSV export');

    $mech->submit_form_ok( { with_fields => {
        name => $counciluser->name,
        email => $counciluser->email,
        body => $counciluser->from_body->id,
        phone => '',
        flagged => undef,
        "permissions[export_extra_columns]" => 'on',
    } } );

    ok $counciluser->has_body_permission_to("export_extra_columns"), "counciluser has been granted CSV extra fields permission";
};

subtest 'extra CSV columns are present if permission granted' => sub {
    $mech->log_in_ok( $counciluser->email );

    $mech->get_ok('/dashboard?export=1');

    my @rows = $mech->content_as_csv;
    is scalar @rows, 5, '1 (header) + 4 (reports) = 5 lines';

    is scalar @{$rows[0]}, 24, '24 columns present';

    is_deeply $rows[0],
        [
            'Report ID',
            'Title',
            'Detail',
            'User Name',
            'Category',
            'Created',
            'Confirmed',
            'Acknowledged',
            'Fixed',
            'Closed',
            'Status',
            'Latitude',
            'Longitude',
            'Query',
            'Ward',
            'Easting',
            'Northing',
            'Report URL',
            'Site Used',
            'Reported As',
            'User Email',
            'User Phone',
            'Staff User',
            'Attribute Data',
        ],
        'Column headers look correct';

    is $rows[1]->[18], 'iOS', 'Site Used shows whether report made via app';
    is $rows[1]->[19], '', 'Reported As is empty if not made on behalf of another user/body';
    is $rows[1]->[20], $normaluser->email, 'User email is correct';
    is $rows[1]->[21], '+447123456789', 'User phone number is correct';
    is $rows[1]->[22], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[1]->[23], 'width = 10cm; depth = 25cm', 'Attribute Data is correct';

    is $rows[2]->[18], 'bathnes', 'Site Used shows correct cobrand';
    is $rows[2]->[19], 'body', 'Reported As is correct if made on behalf of body';
    is $rows[2]->[20], $counciluser->email, 'User email is correct';
    is $rows[2]->[21], '', 'User phone number is correct';
    is $rows[2]->[22], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[2]->[23], '', 'Attribute Data is correct';

    is $rows[3]->[18], 'bathnes', 'Site Used shows correct cobrand';
    is $rows[3]->[19], 'another_user', 'Reported As is set if reported on behalf of another user';
    is $rows[3]->[20], $normaluser->email, 'User email is correct';
    is $rows[3]->[21], '+447123456789', 'User phone number is correct';
    is $rows[3]->[22], $counciluser->email, 'Staff User is correct if made on behalf of another user';
    is $rows[3]->[23], '', 'Attribute Data is correct';

    is $rows[4]->[18], 'bathnes', 'Site Used shows correct cobrand';
    is $rows[4]->[19], 'anonymous_user', 'Reported As is set if reported on behalf of another user';
    is $rows[4]->[20], $counciluser->email, 'User email is correct';
    is $rows[4]->[21], '', 'User phone number is correct';
    is $rows[4]->[22], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[4]->[23], '', 'Attribute Data is correct';

    $mech->get_ok('/dashboard?export=1&updates=1');

    @rows = $mech->content_as_csv;
    is scalar @rows, 1, '1 (header) + 0 (updates)';
    is scalar @{$rows[0]}, 10, '10 columns present';
    is_deeply $rows[0],
        [
            'Report ID', 'Update ID', 'Date', 'Status', 'Problem state',
            'Text', 'User Name', 'Reported As', 'Staff User',
            'User Email',
        ],
        'Column headers look correct';
};


};

subtest 'check cobrand correctly reset on each request' => sub {
    FixMyStreet::override_config {
        'ALLOWED_COBRANDS' => [ 'bathnes', 'fixmystreet' ],
    }, sub {
        $mech->log_in_ok( $superuser->email );
        $mech->host('www.fixmystreet.com');
        $mech->get_ok( '/contact?id=' . $problem->id );
        $mech->host('bathnes.fixmystreet.com');
        $mech->get_ok( '/contact?reject=1&id=' . $problem->id );
        $mech->content_contains('Reject report');
    }
};

done_testing();
