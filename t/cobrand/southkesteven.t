use FixMyStreet::TestMech;
use FixMyStreet::Script::CSVExport;
use File::Temp 'tempdir';

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $south_kesteven = $mech->create_body_ok(2380, 'South Kesteven District Council', { cobrand => 'southkesteven' });
my $contact = $mech->create_contact_ok( body_id => $south_kesteven->id, category => 'Graffiti', email => 'graffiti@example.org' );
my $standard_user = $mech->create_user_ok( 'user@example.com', name => 'User' );
my $staff_user = $mech->create_user_ok( 'staff@example.com', name => 'Staff', from_body => $south_kesteven->id );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'southkesteven',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        updates_allowed => {
            southkesteven => 'reporter/staff'
        }
    }
}, sub {
    my ($report) = $mech->create_problems_for_body(
        1,
        $south_kesteven->id,
        'A report',
        {   user     => $standard_user,
            category => 'Graffiti',
        },
    );

    subtest "Reporter can't close / fix an open report via an update" => sub {
        ok $report->is_open;
        $mech->log_in_ok( $standard_user->email );
        $mech->get_ok( '/report/' . $report->id );
        $mech->content_like(
            qr/textarea.*id="form_update"/,
            'can leave text update',
        );
        $mech->content_unlike(
            qr/select.*id="state"/,
            'no state dropdown',
        );
        $mech->content_unlike(
            qr/input.*id="form_fixed"/,
            'no checkbox for fixed',
        );
    };

    $report->update({ state => 'closed' });
    subtest "Reporter can reopen a closed report" => sub {
        ok !$report->is_open;
        $mech->get_ok( '/report/' . $report->id );

        $mech->content_like(
            qr/textarea.*id="form_update"/,
            'can leave text update',
        );
        $mech->content_unlike(
            qr/select.*id="state"/,
            'no state dropdown',
        );
        $mech->content_like(
            qr/input.*id="form_reopen"/,
            'has checkbox for reopen',
        );
    };
};

subtest 'Dashboard CSV extra columns' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'southkesteven',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $south_kesteven->id, 'Problem', {
            areas => "2488", category => 'Flytipping', cobrand => 'southkesteven', state => 'confirmed'});
        $problem->set_extra_fields(
            {name => 'type_of_waste', value => 'garden'},
            {name => 'how_much', value => 'small_van'},
            {name => 'location', value => 'highway'},
        );
        $problem->update;
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Reported As","Type of waste","How much waste",Location');
        ok $mech->content_contains('southkesteven,,garden,small_van,highway');
    };
};

subtest 'Dashboard CSV pre-generation' => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'southkesteven',
        MAPIT_URL => 'http://mapit.uk/',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Reported As","Type of waste","How much waste",Location');
        ok $mech->content_contains('southkesteven,,garden,small_van,highway');
    };
};

done_testing();
